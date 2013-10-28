/*
 * file-transfer-chan.c - Simple file transfer channel
 *
 * Copyright (C) 2010-2011 Morten Mjelva <morten.mjelva@gmail.com>
 * Copyright (C) 2010-2011 Collabora Ltd. <http://www.collabora.co.uk/>
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#include "config.h"

#include "file-transfer-chan.h"
#include "util.h"
#include "debug.h"

#include <telepathy-glib/telepathy-glib.h>
#include <telepathy-glib/telepathy-glib-dbus.h>

#include <glib/gstdio.h>

static void file_transfer_iface_init (gpointer iface, gpointer data);

G_DEFINE_TYPE_WITH_CODE (TpTestsFileTransferChannel,
    tp_tests_file_transfer_channel,
    TP_TYPE_BASE_CHANNEL,
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CHANNEL_TYPE_FILE_TRANSFER1,
      file_transfer_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CHANNEL_INTERFACE_FILE_TRANSFER_METADATA1,
      NULL);
    )

enum /* properties */
{
  PROP_AVAILABLE_SOCKET_TYPES = 1,
  PROP_CONTENT_TYPE,
  PROP_CONTENT_HASH,
  PROP_CONTENT_HASH_TYPE,
  PROP_DATE,
  PROP_DESCRIPTION,
  PROP_FILENAME,
  PROP_INITIAL_OFFSET,
  PROP_SIZE,
  PROP_STATE,
  PROP_TRANSFERRED_BYTES,
  PROP_URI,
  PROP_SERVICE_NAME,
  PROP_METADATA,
  N_PROPS,
};

struct _TpTestsFileTransferChannelPrivate {
    /* Exposed properties */
    gchar *content_type;
    guint64 date;
    gchar *description;
    gchar *filename;
    guint64 size;
    TpFileTransferState state;
    guint64 transferred_bytes;
    gchar *uri;
    gchar *service_name;
    GHashTable *metadata;

    /* Hidden properties */
    TpFileHashType content_hash_type;
    gchar *content_hash;
    GHashTable *available_socket_types;
    gint64 initial_offset;

    /* Accepting side */
    GSocketService *service;
    GValue *access_control_param;

    /* Offering side */
    TpSocketAddressType address_type;
    GValue *address;
    gchar *unix_address;
    gchar *unix_tmpdir;
    guint connection_id;
    TpSocketAccessControl access_control;

    guint timer_id;
};

static void
tp_tests_file_transfer_channel_init (TpTestsFileTransferChannel *self)
{
  self->priv = G_TYPE_INSTANCE_GET_PRIVATE ((self),
      TP_TESTS_TYPE_FILE_TRANSFER_CHANNEL, TpTestsFileTransferChannelPrivate);
}

static void
create_available_socket_types (TpTestsFileTransferChannel *self)
{
  TpSocketAccessControl access_control;
  GArray *unix_tab;

  g_assert (self->priv->available_socket_types == NULL);
  self->priv->available_socket_types = g_hash_table_new_full (NULL, NULL,
      NULL, _tp_destroy_socket_control_list);

  /* SocketAddressTypeUnix */
  unix_tab = g_array_sized_new (FALSE, FALSE, sizeof (TpSocketAccessControl),
      1);
  access_control = TP_SOCKET_ACCESS_CONTROL_LOCALHOST;
  g_array_append_val (unix_tab, access_control);

  g_hash_table_insert (self->priv->available_socket_types,
      GUINT_TO_POINTER (TP_SOCKET_ADDRESS_TYPE_UNIX), unix_tab);
}

static GObject *
constructor (GType type,
    guint n_props,
    GObjectConstructParam *props)
{
  GObject *object =
    G_OBJECT_CLASS (tp_tests_file_transfer_channel_parent_class)->constructor
    (type, n_props, props);
  TpTestsFileTransferChannel *self = TP_TESTS_FILE_TRANSFER_CHANNEL (object);

  self->priv->state = TP_FILE_TRANSFER_STATE_PENDING;

  if (self->priv->available_socket_types == NULL)
    create_available_socket_types (self);

  tp_base_channel_register (TP_BASE_CHANNEL (self));

  return object;
}

static void
dispose (GObject *object)
{
  TpTestsFileTransferChannel *self = TP_TESTS_FILE_TRANSFER_CHANNEL (object);

  if (self->priv->timer_id != 0)
    {
      g_source_remove (self->priv->timer_id);
      self->priv->timer_id = 0;
    }

  g_free (self->priv->content_hash);
  g_free (self->priv->content_type);
  g_free (self->priv->description);
  g_free (self->priv->filename);
  g_free (self->priv->uri);
  g_free (self->priv->service_name);

  tp_clear_pointer (&self->priv->address, tp_g_value_slice_free);
  tp_clear_pointer (&self->priv->available_socket_types, g_hash_table_unref);
  tp_clear_pointer (&self->priv->access_control_param, tp_g_value_slice_free);
  tp_clear_pointer (&self->priv->metadata, g_hash_table_unref);

  if (self->priv->unix_address != NULL)
    g_unlink (self->priv->unix_address);

  tp_clear_pointer (&self->priv->unix_address, g_free);

  if (self->priv->unix_tmpdir != NULL)
    g_rmdir (self->priv->unix_tmpdir);

  tp_clear_pointer (&self->priv->unix_tmpdir, g_free);

  ((GObjectClass *) tp_tests_file_transfer_channel_parent_class)->dispose (
      object);
}

static void
get_property (GObject *object,
    guint property_id,
    GValue *value,
    GParamSpec *pspec)
{
  TpTestsFileTransferChannel *self = (TpTestsFileTransferChannel *) object;

  switch (property_id)
    {
      case PROP_AVAILABLE_SOCKET_TYPES:
        g_value_set_boxed (value, self->priv->available_socket_types);
        break;

      case PROP_CONTENT_HASH:
        g_value_set_string (value, self->priv->content_hash);

      case PROP_CONTENT_HASH_TYPE:
        g_value_set_uint (value, self->priv->content_hash_type);
        break;

      case PROP_CONTENT_TYPE:
        g_value_set_string (value, self->priv->content_type);
        break;

      case PROP_DATE:
        g_value_set_uint64 (value, self->priv->date);
        break;

      case PROP_DESCRIPTION:
        g_value_set_string (value, self->priv->description);
        break;

      case PROP_FILENAME:
        g_value_set_string (value, self->priv->filename);
        break;

      case PROP_INITIAL_OFFSET:
        g_value_set_uint64 (value, self->priv->initial_offset);
        break;

      case PROP_SIZE:
        g_value_set_uint64 (value, self->priv->size);
        break;

      case PROP_STATE:
        g_value_set_uint (value, self->priv->state);
        break;

      case PROP_TRANSFERRED_BYTES:
        g_value_set_uint64 (value, self->priv->transferred_bytes);
        break;

      case PROP_URI:
        g_value_set_string (value, self->priv->uri);
        break;

      case PROP_SERVICE_NAME:
        g_value_set_string (value, self->priv->service_name);
        break;

      case PROP_METADATA:
        g_value_set_boxed (value, self->priv->metadata);
        break;

      default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
set_property (GObject *object,
    guint property_id,
    const GValue *value,
    GParamSpec *pspec)
{
  TpTestsFileTransferChannel *self = (TpTestsFileTransferChannel *) object;

  switch (property_id)
    {
      case PROP_AVAILABLE_SOCKET_TYPES:
        self->priv->available_socket_types = g_value_dup_boxed (value);
        break;

      case PROP_CONTENT_HASH:
        self->priv->content_hash = g_value_dup_string (value);
        break;

      case PROP_CONTENT_HASH_TYPE:
        break;

      case PROP_CONTENT_TYPE:
        self->priv->content_type = g_value_dup_string (value);
        break;

      case PROP_DATE:
        self->priv->date = g_value_get_uint64 (value);
        break;

      case PROP_DESCRIPTION:
        self->priv->description = g_value_dup_string (value);
        break;

      case PROP_FILENAME:
        self->priv->filename = g_value_dup_string (value);
        break;

      case PROP_INITIAL_OFFSET:
        self->priv->initial_offset = g_value_get_uint64 (value);
        break;

      case PROP_SIZE:
        self->priv->size = g_value_get_uint64 (value);
        break;

      case PROP_STATE:
        self->priv->state = g_value_get_uint (value);
        break;

      case PROP_TRANSFERRED_BYTES:
        self->priv->transferred_bytes = g_value_get_uint64 (value);
        break;

      case PROP_URI:
        self->priv->uri = g_value_dup_string (value);
        break;

      case PROP_SERVICE_NAME:
        self->priv->service_name = g_value_dup_string (value);
        break;

      case PROP_METADATA:
        self->priv->metadata = g_value_dup_boxed (value);
        break;

      default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
channel_close (TpBaseChannel *self)
{
  g_print ("entered channel_close");
  tp_base_channel_destroyed (self);
}

static void
fill_immutable_properties (TpBaseChannel *self,
    GHashTable *properties)
{
  TpBaseChannelClass *klass = TP_BASE_CHANNEL_CLASS (
      tp_tests_file_transfer_channel_parent_class);

  klass->fill_immutable_properties (self, properties);

  tp_dbus_properties_mixin_fill_properties_hash (
      G_OBJECT (self), properties,
      TP_IFACE_CHANNEL_TYPE_FILE_TRANSFER1, "AvailableSocketTypes",
      TP_IFACE_CHANNEL_TYPE_FILE_TRANSFER1, "ContentType",
      TP_IFACE_CHANNEL_TYPE_FILE_TRANSFER1, "Filename",
      TP_IFACE_CHANNEL_TYPE_FILE_TRANSFER1, "Size",
      TP_IFACE_CHANNEL_TYPE_FILE_TRANSFER1, "Description",
      TP_IFACE_CHANNEL_TYPE_FILE_TRANSFER1, "Date",
      TP_IFACE_CHANNEL_INTERFACE_FILE_TRANSFER_METADATA1, "ServiceName",
      TP_IFACE_CHANNEL_INTERFACE_FILE_TRANSFER_METADATA1, "Metadata",
      NULL);

  /* URI is immutable only for outgoing transfers */
  if (tp_base_channel_is_requested (self))
    {
      tp_dbus_properties_mixin_fill_properties_hash (G_OBJECT (self),
          properties,
          TP_IFACE_CHANNEL_TYPE_FILE_TRANSFER1, "URI", NULL);
    }
}

static void
change_state (TpTestsFileTransferChannel *self,
    TpFileTransferState state,
    TpFileTransferStateChangeReason reason)
{
  self->priv->state = state;

  tp_svc_channel_type_file_transfer1_emit_file_transfer_state_changed (self,
      state, reason);
}

/* This function imitates the beginning of a filetransfer. It sets the state
 * to open, and connects to the "incoming" signal of the GSocketService.
 */
static gboolean
start_file_transfer (gpointer data)
{
  TpTestsFileTransferChannel *self = (TpTestsFileTransferChannel *) data;

  DEBUG ("Setting TP_FILE_TRANSFER_STATE_OPEN");
  change_state (self, TP_FILE_TRANSFER_STATE_OPEN,
      TP_FILE_TRANSFER_STATE_CHANGE_REASON_REQUESTED);

  g_object_notify ((GObject *) data, "state");
  DEBUG ("Fired state signal");

//  g_signal_connect (self->priv->service, "incoming", G_CALLBACK
//      (incoming_file_transfer_cb));

  self->priv->timer_id = 0;
  return FALSE;
}

static gboolean
check_address_type (TpTestsFileTransferChannel *self,
    TpSocketAddressType address_type,
    TpSocketAccessControl access_control)
{
  GArray *arr;
  guint i;

  arr = g_hash_table_lookup (self->priv->available_socket_types,
      GUINT_TO_POINTER (address_type));
  if (arr == NULL)
    return FALSE;

  for (i = 0; i < arr->len; i++)
    {
      if (g_array_index (arr, TpSocketAccessControl, i) == access_control)
        return TRUE;
    }

  return FALSE;
}

static void
service_incoming_cb (GSocketService *service,
    GSocketConnection *connection,
    GObject *source_object,
    gpointer user_data)
{
  TpTestsFileTransferChannel *self = user_data;
  GError *error = NULL;

  DEBUG ("Servicing incoming connection");
  if (self->priv->access_control == TP_SOCKET_ACCESS_CONTROL_CREDENTIALS)
    {
      GCredentials *creds;
      guchar byte;

      /* TODO: Async version */
      creds = tp_unix_connection_receive_credentials_with_byte (
          connection, &byte, NULL, &error);
      g_assert_no_error (error);

      g_assert_cmpuint (byte, ==,
          g_value_get_uchar (self->priv->access_control_param));
      g_object_unref (creds);
    }
  else if (self->priv->access_control == TP_SOCKET_ACCESS_CONTROL_PORT)
    {
      GSocketAddress *addr;
      guint16 port;

      addr = g_socket_connection_get_remote_address (connection, &error);
      g_assert_no_error (error);

      port = g_inet_socket_address_get_port (G_INET_SOCKET_ADDRESS (addr));

      g_assert_cmpuint (port, ==,
          g_value_get_uint (self->priv->access_control_param));

      g_object_unref (addr);
    }
}

static void
file_transfer_provide_file (TpSvcChannelTypeFileTransfer1 *iface,
    TpSocketAddressType address_type,
    TpSocketAccessControl access_control,
    const GValue *access_control_param,
    DBusGMethodInvocation *context)
{
  TpTestsFileTransferChannel *self = (TpTestsFileTransferChannel *) iface;
  TpBaseChannel *base_chan = (TpBaseChannel *) iface;
  GError *error = NULL;

  if (tp_base_channel_is_requested (base_chan) != TRUE)
    {
      g_set_error (&error, TP_ERROR, TP_ERROR_INVALID_ARGUMENT,
          "File transfer is not outgoing. Cannot offer file");
      goto fail;
    }

  if (self->priv->state != TP_FILE_TRANSFER_STATE_PENDING &&
      self->priv->state != TP_FILE_TRANSFER_STATE_ACCEPTED)
    {
      g_set_error (&error, TP_ERROR, TP_ERROR_INVALID_ARGUMENT,
          "File transfer is not pending or accepted. Cannot offer file");
      goto fail;
    }

  if (self->priv->address != NULL)
    {
      g_set_error (&error, TP_ERROR, TP_ERROR_NOT_AVAILABLE,
          "ProvideFile has already been called for this channel");
      goto fail;
    }

  if (!check_address_type (self, address_type, access_control))
    {
      g_set_error (&error, TP_ERROR, TP_ERROR_INVALID_ARGUMENT,
          "Address type %i is not supported with access control %i",
          address_type, access_control);
      goto fail;
    }

  self->priv->address = _tp_create_local_socket (address_type, access_control,
      &self->priv->service, &self->priv->unix_address,
      &self->priv->unix_tmpdir, &error);

  if (self->priv->address == NULL)
      {
        g_set_error (&error, TP_ERROR, TP_ERROR_NOT_AVAILABLE,
            "Could not set up local socket");
        goto fail;
      }

  self->priv->address_type = address_type;
  self->priv->access_control = access_control;

  DEBUG ("Waiting 500ms and setting state to OPEN");
  self->priv->timer_id = g_timeout_add (500, start_file_transfer, self);

  // connect to self->priv->service incoming signal
  // when the signal returns, add x bytes per n seconds using timeout
  // then close the socket
  // g_output_stream_write_async

  tp_svc_channel_type_file_transfer1_return_from_provide_file (context,
      self->priv->address);

  return;

fail:
  dbus_g_method_return_error (context, error);
  g_error_free (error);
}

static void
file_transfer_accept_file (TpSvcChannelTypeFileTransfer1 *iface,
    TpSocketAddressType address_type,
    TpSocketAccessControl access_control,
    const GValue *access_control_param,
    guint64 offset,
    DBusGMethodInvocation *context)
{
  TpTestsFileTransferChannel *self = (TpTestsFileTransferChannel *) iface;
  TpBaseChannel *base_chan = (TpBaseChannel *) iface;
  GError *error = NULL;
  GValue *address;

  if (tp_base_channel_is_requested (base_chan) == TRUE)
    {
      g_set_error (&error, TP_ERROR, TP_ERROR_INVALID_ARGUMENT,
          "File transfer is not incoming. Cannot accept file");
      goto fail;
    }

  if (self->priv->state != TP_FILE_TRANSFER_STATE_PENDING)
    {
      g_set_error (&error, TP_ERROR, TP_ERROR_INVALID_ARGUMENT,
          "File transfer is not in the pending state");
      goto fail;
    }

  if (!check_address_type (self, address_type, access_control))
    {
      g_set_error (&error, TP_ERROR, TP_ERROR_INVALID_ARGUMENT,
          "Address type %i is not supported with access control %i",
          address_type, access_control);
      goto fail;
    }

  address = _tp_create_local_socket (address_type, access_control,
      &self->priv->service, &self->priv->unix_address,
      &self->priv->unix_tmpdir, &error);

  tp_g_signal_connect_object (self->priv->service, "incoming",
      G_CALLBACK (service_incoming_cb), self, 0);

  self->priv->access_control = access_control;
  self->priv->access_control_param = tp_g_value_slice_dup (
      access_control_param);

  DEBUG ("Setting TP_FILE_TRANSFER_STATE_ACCEPTED");
  change_state (self, TP_FILE_TRANSFER_STATE_ACCEPTED,
      TP_FILE_TRANSFER_STATE_CHANGE_REASON_REQUESTED);

  DEBUG ("Waiting 500ms and setting state to OPEN");
  self->priv->timer_id = g_timeout_add (500, start_file_transfer, self);

  tp_svc_channel_type_file_transfer1_return_from_accept_file (context,
      address);

  tp_clear_pointer (&address, tp_g_value_slice_free);

  return;

fail:
  dbus_g_method_return_error (context, error);
  g_error_free (error);
}

static void
tp_tests_file_transfer_channel_class_init (
    TpTestsFileTransferChannelClass *klass)
{
  GObjectClass *object_class = (GObjectClass *) klass;
  TpBaseChannelClass *base_class = TP_BASE_CHANNEL_CLASS (klass);
  GParamSpec *param_spec;

  static TpDBusPropertiesMixinPropImpl file_transfer_props[] = {
      { "AvailableSocketTypes", "available-socket-types", NULL },
      { "ContentType", "content-type", NULL },
      { "Date", "date", NULL },
      { "Description", "description", NULL },
      { "Filename", "filename", NULL },
      { "Size", "size", NULL },
      { "State", "state", NULL },
      { "TransferredBytes", "transferred-bytes", NULL },
      { "URI", "uri", NULL },
      { NULL }
  };

  static TpDBusPropertiesMixinPropImpl metadata_props[] = {
      { "ServiceName", "service-name", NULL },
      { "Metadata", "metadata", NULL },
      { NULL }
  };

  object_class->constructor = constructor;
  object_class->get_property = get_property;
  object_class->set_property = set_property;
  object_class->dispose = dispose;

  base_class->channel_type = TP_IFACE_CHANNEL_TYPE_FILE_TRANSFER1;
  base_class->target_handle_type = TP_HANDLE_TYPE_CONTACT;

  base_class->close = channel_close;
  base_class->fill_immutable_properties = fill_immutable_properties;

  param_spec = g_param_spec_boxed ("available-socket-types",
      "AvailableSocketTypes",
      "The AvailableSocketTypes property of this channel",
      TP_HASH_TYPE_SUPPORTED_SOCKET_MAP,
      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_AVAILABLE_SOCKET_TYPES,
      param_spec);

  param_spec = g_param_spec_string ("content-type",
      "ContentType",
      "The ContentType property of this channel",
      NULL,
      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_CONTENT_TYPE,
      param_spec);

  param_spec = g_param_spec_uint64 ("date",
      "Date",
      "The Date property of this channel",
      0, G_MAXUINT64, 0,
      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_DATE,
      param_spec);

  param_spec = g_param_spec_string ("description",
      "Description",
      "The Description property of this channel",
      NULL,
      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_DESCRIPTION,
      param_spec);

  param_spec = g_param_spec_string ("filename",
      "Filename",
      "The Filename property of this channel",
      NULL,
      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_FILENAME,
      param_spec);

  param_spec = g_param_spec_uint64 ("initial-offset",
      "InitialOffset",
      "The InitialOffset property of this channel",
      0, G_MAXUINT64, 0,
      G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_INITIAL_OFFSET,
      param_spec);

  param_spec = g_param_spec_uint64 ("size",
      "Size",
      "The Size property of this channel",
      0, G_MAXUINT64, 0,
      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_SIZE,
      param_spec);

  param_spec = g_param_spec_uint ("state",
      "State",
      "The State property of this channel",
      0, TP_NUM_FILE_TRANSFER_STATES, TP_FILE_TRANSFER_STATE_NONE,
      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_STATE,
      param_spec);

  param_spec = g_param_spec_uint64 ("transferred-bytes",
      "TransferredBytes",
      "The TransferredBytes property of this channel",
      0, G_MAXUINT64, 0,
      G_PARAM_READABLE | G_PARAM_WRITABLE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_TRANSFERRED_BYTES,
      param_spec);

  param_spec = g_param_spec_string ("uri",
      "URI",
      "The URI property of this channel",
      NULL,
      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_URI,
      param_spec);

  param_spec = g_param_spec_string ("service-name",
      "ServiceName",
      "The Metadata.ServiceName property of this channel",
      "",
      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_SERVICE_NAME,
      param_spec);

  param_spec = g_param_spec_boxed ("metadata",
      "Metadata",
      "The Metadata.Metadata property of this channel",
      TP_HASH_TYPE_METADATA,
      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_METADATA,
      param_spec);

  tp_dbus_properties_mixin_implement_interface (object_class,
      TP_IFACE_QUARK_CHANNEL_TYPE_FILE_TRANSFER1,
      tp_dbus_properties_mixin_getter_gobject_properties, NULL,
      file_transfer_props);

  tp_dbus_properties_mixin_implement_interface (object_class,
      TP_IFACE_QUARK_CHANNEL_INTERFACE_FILE_TRANSFER_METADATA1,
      tp_dbus_properties_mixin_getter_gobject_properties, NULL,
      metadata_props);

  g_type_class_add_private (object_class,
      sizeof (TpTestsFileTransferChannelPrivate));
}

static void
file_transfer_iface_init (gpointer iface, gpointer data)
{
  TpSvcChannelTypeFileTransfer1Class *klass = iface;

#define IMPLEMENT(x) tp_svc_channel_type_file_transfer1_implement_##x (klass, \
    file_transfer_##x)
  IMPLEMENT(accept_file);
  IMPLEMENT(provide_file);
#undef IMPLEMENT
}

/* Return the address of the file transfer's socket */
GSocketAddress *
tp_tests_file_transfer_channel_get_server_address (
    TpTestsFileTransferChannel *self)
{
  GSocketAddress *address;
  GError *error = NULL;

  g_assert (self->priv->address != NULL);

  address = tp_g_socket_address_from_variant (self->priv->address_type,
      self->priv->address, &error);

  if (error != NULL)
    {
      g_printf ("%s\n", error->message);
    }

  return address;
}
