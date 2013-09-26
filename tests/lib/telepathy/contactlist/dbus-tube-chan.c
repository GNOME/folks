/*
 * dbus-tube-chan.c - Simple dbus tube channel
 *
 * Copyright (C) 2010 Collabora Ltd. <http://www.collabora.co.uk/>
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#include "config.h"

#include "dbus-tube-chan.h"

#include <telepathy-glib/telepathy-glib.h>
#include <telepathy-glib/telepathy-glib-dbus.h>
#include <glib/gstdio.h>

#if defined(G_OS_UNIX)
#   define LISTEN_ADDRESS "unix:tmpdir=/tmp"
#else
#   define LISTEN_ADDRESS "tcp:host=127.0.0.1"
#endif

enum
{
  PROP_SERVICE_NAME = 1,
  PROP_DBUS_NAMES,
  PROP_SUPPORTED_ACCESS_CONTROLS,
  PROP_PARAMETERS,
  PROP_STATE,
};

enum
{
  SIG_NEW_CONNECTION,
  LAST_SIGNAL
};

static guint _signals[LAST_SIGNAL] = { 0, };

struct _TpTestsDBusTubeChannelPrivate {
    /* Controls whether the channel should become open before returning from
     * Open/Accept, after returning, or never.
     */
    TpTestsDBusTubeChannelOpenMode open_mode;
    TpTubeChannelState state;

    /* TpHandle -> gchar * */
    GHashTable *dbus_names;

    GDBusServer *dbus_server;
};

static void
tp_tests_dbus_tube_channel_get_property (GObject *object,
    guint property_id,
    GValue *value,
    GParamSpec *pspec)
{
  TpTestsDBusTubeChannel *self = (TpTestsDBusTubeChannel *) object;

  switch (property_id)
    {
      case PROP_SERVICE_NAME:
        g_value_set_string (value, "com.test.Test");
        break;

      case PROP_DBUS_NAMES:
        g_value_set_boxed (value, self->priv->dbus_names);
        break;

      case PROP_SUPPORTED_ACCESS_CONTROLS:
        {
          GArray *array;
          TpSocketAccessControl a;

          array = g_array_sized_new (FALSE, FALSE, sizeof (guint), 1);

          a = TP_SOCKET_ACCESS_CONTROL_LOCALHOST;
          g_array_append_val (array, a);

          g_value_set_boxed (value, array);

          g_array_unref (array);
        }
        break;

      case PROP_PARAMETERS:
        g_value_take_boxed (value, tp_asv_new (
              "badger", G_TYPE_UINT, 42,
              NULL));
        break;

      case PROP_STATE:
        g_value_set_uint (value, self->priv->state);
        break;

      default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void dbus_tube_iface_init (gpointer iface, gpointer data);

G_DEFINE_ABSTRACT_TYPE_WITH_CODE (TpTestsDBusTubeChannel,
    tp_tests_dbus_tube_channel,
    TP_TYPE_BASE_CHANNEL,
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CHANNEL_TYPE_DBUS_TUBE,
      dbus_tube_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CHANNEL_INTERFACE_TUBE,
      NULL);
    )

/* type definition stuff */

static GPtrArray *
tp_tests_dbus_tube_channel_get_interfaces (TpBaseChannel *self)
{
  GPtrArray *interfaces;

  interfaces = TP_BASE_CHANNEL_CLASS (
      tp_tests_dbus_tube_channel_parent_class)->get_interfaces (self);

  g_ptr_array_add (interfaces, TP_IFACE_CHANNEL_INTERFACE_TUBE);
  return interfaces;
};

static void
tp_tests_dbus_tube_channel_init (TpTestsDBusTubeChannel *self)
{
  self->priv = G_TYPE_INSTANCE_GET_PRIVATE ((self),
      TP_TESTS_TYPE_DBUS_TUBE_CHANNEL, TpTestsDBusTubeChannelPrivate);

  self->priv->open_mode = TP_TESTS_DBUS_TUBE_CHANNEL_OPEN_FIRST;
  self->priv->dbus_names = g_hash_table_new_full (g_direct_hash,
      g_direct_equal, NULL, g_free);
}

static GObject *
constructor (GType type,
             guint n_props,
             GObjectConstructParam *props)
{
  GObject *object =
      G_OBJECT_CLASS (tp_tests_dbus_tube_channel_parent_class)->constructor (
          type, n_props, props);
  TpTestsDBusTubeChannel *self = TP_TESTS_DBUS_TUBE_CHANNEL (object);

  if (tp_base_channel_is_requested (TP_BASE_CHANNEL (self)))
    self->priv->state = TP_TUBE_CHANNEL_STATE_NOT_OFFERED;
  else
    self->priv->state = TP_TUBE_CHANNEL_STATE_LOCAL_PENDING;

  tp_base_channel_register (TP_BASE_CHANNEL (self));

  return object;
}

static void
dispose (GObject *object)
{
  TpTestsDBusTubeChannel *self = (TpTestsDBusTubeChannel *) object;

  tp_clear_pointer (&self->priv->dbus_names, g_hash_table_unref);

  if (self->priv->dbus_server != NULL)
    {
      /* FIXME: this is pretty stupid but apparently unless you start and then
       * stop the server before freeing it, it doesn't stop listening. Calling
       * _start() twice is a no-op.
       *
       * https://bugzilla.gnome.org/show_bug.cgi?id=673372
      */
      g_dbus_server_start (self->priv->dbus_server);

      g_dbus_server_stop (self->priv->dbus_server);
      g_clear_object (&self->priv->dbus_server);
    }

  ((GObjectClass *) tp_tests_dbus_tube_channel_parent_class)->dispose (
    object);
}

static void
channel_close (TpBaseChannel *channel)
{
  tp_base_channel_destroyed (channel);
}

static void
fill_immutable_properties (TpBaseChannel *chan,
    GHashTable *properties)
{
  TpBaseChannelClass *klass = TP_BASE_CHANNEL_CLASS (
      tp_tests_dbus_tube_channel_parent_class);

  klass->fill_immutable_properties (chan, properties);

  tp_dbus_properties_mixin_fill_properties_hash (
      G_OBJECT (chan), properties,
      TP_IFACE_CHANNEL_TYPE_DBUS_TUBE, "ServiceName",
      TP_IFACE_CHANNEL_TYPE_DBUS_TUBE, "SupportedAccessControls",
      NULL);

  if (!tp_base_channel_is_requested (chan))
    {
      /* Parameters is immutable only for incoming tubes */
      tp_dbus_properties_mixin_fill_properties_hash (
          G_OBJECT (chan), properties,
          TP_IFACE_CHANNEL_INTERFACE_TUBE, "Parameters",
          NULL);
    }
}

static void
tp_tests_dbus_tube_channel_class_init (TpTestsDBusTubeChannelClass *klass)
{
  GObjectClass *object_class = (GObjectClass *) klass;
  TpBaseChannelClass *base_class = TP_BASE_CHANNEL_CLASS (klass);
  GParamSpec *param_spec;
  static TpDBusPropertiesMixinPropImpl dbus_tube_props[] = {
      { "ServiceName", "service-name", NULL, },
      { "DBusNames", "dbus-names", NULL, },
      { "SupportedAccessControls", "supported-access-controls", NULL, },
      { NULL }
  };
  static TpDBusPropertiesMixinPropImpl tube_props[] = {
      { "Parameters", "parameters", NULL, },
      { "State", "state", NULL, },
      { NULL }
  };

  object_class->constructor = constructor;
  object_class->get_property = tp_tests_dbus_tube_channel_get_property;
  object_class->dispose = dispose;

  base_class->channel_type = TP_IFACE_CHANNEL_TYPE_DBUS_TUBE;
  base_class->get_interfaces = tp_tests_dbus_tube_channel_get_interfaces;
  base_class->close = channel_close;
  base_class->fill_immutable_properties = fill_immutable_properties;

  /* base_class->target_handle_type is defined in subclasses */

  param_spec = g_param_spec_string ("service-name", "Service Name",
      "the service name associated with this tube object.",
       "",
       G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_SERVICE_NAME, param_spec);

  param_spec = g_param_spec_boxed ("dbus-names", "DBus Names",
      "DBusTube.DBusNames",
      TP_HASH_TYPE_DBUS_TUBE_PARTICIPANTS,
       G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_DBUS_NAMES, param_spec);

  param_spec = g_param_spec_boxed ("supported-access-controls",
      "Supported access-controls",
      "GArray containing supported access controls.",
      DBUS_TYPE_G_UINT_ARRAY,
      G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class,
      PROP_SUPPORTED_ACCESS_CONTROLS, param_spec);

  param_spec = g_param_spec_boxed (
      "parameters", "Parameters",
      "parameters of the tube",
      TP_HASH_TYPE_STRING_VARIANT_MAP,
      G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_PARAMETERS,
      param_spec);

  param_spec = g_param_spec_uint (
      "state", "TpTubeState",
      "state of the tube",
      0, TP_NUM_TUBE_CHANNEL_STATES - 1, 0,
      G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_STATE,
      param_spec);

  _signals[SIG_NEW_CONNECTION] = g_signal_new ("new-connection",
      G_OBJECT_CLASS_TYPE (klass),
      G_SIGNAL_RUN_LAST,
      0,
      g_signal_accumulator_true_handled, NULL,
      NULL,
      G_TYPE_BOOLEAN,
      1, G_TYPE_DBUS_CONNECTION);

  tp_dbus_properties_mixin_implement_interface (object_class,
      TP_IFACE_QUARK_CHANNEL_TYPE_DBUS_TUBE,
      tp_dbus_properties_mixin_getter_gobject_properties, NULL,
      dbus_tube_props);

  tp_dbus_properties_mixin_implement_interface (object_class,
      TP_IFACE_QUARK_CHANNEL_INTERFACE_TUBE,
      tp_dbus_properties_mixin_getter_gobject_properties, NULL,
      tube_props);

  g_type_class_add_private (object_class,
      sizeof (TpTestsDBusTubeChannelPrivate));
}

static void
change_state (TpTestsDBusTubeChannel *self,
  TpTubeChannelState state)
{
  self->priv->state = state;

  tp_svc_channel_interface_tube_emit_tube_channel_state_changed (self, state);
}

static gboolean
dbus_new_connection_cb (GDBusServer *server,
    GDBusConnection *connection,
    gpointer user_data)
{
  TpTestsDBusTubeChannel *self = user_data;
  gboolean ret = FALSE;

  g_signal_emit (self, _signals[SIG_NEW_CONNECTION], 0, connection, &ret);
  return ret;
}

static void
open_tube (TpTestsDBusTubeChannel *self)
{
  GError *error = NULL;
  gchar *guid;

  guid = g_dbus_generate_guid ();

  self->priv->dbus_server = g_dbus_server_new_sync (LISTEN_ADDRESS,
      G_DBUS_SERVER_FLAGS_NONE, guid, NULL, NULL, &error);
  g_assert_no_error (error);

  g_free (guid);

  g_signal_connect (self->priv->dbus_server, "new-connection",
      G_CALLBACK (dbus_new_connection_cb), self);
}

static void
really_open_tube (TpTestsDBusTubeChannel *self)
{
  g_dbus_server_start (self->priv->dbus_server);

  change_state (self, TP_TUBE_CHANNEL_STATE_OPEN);
}

static void
dbus_tube_offer (TpSvcChannelTypeDBusTube *chan,
    GHashTable *parameters,
    guint access_control,
    DBusGMethodInvocation *context)
{
  TpTestsDBusTubeChannel *self = (TpTestsDBusTubeChannel *) chan;

  open_tube (self);

  if (self->priv->open_mode == TP_TESTS_DBUS_TUBE_CHANNEL_OPEN_FIRST)
    really_open_tube (self);

  tp_svc_channel_type_dbus_tube_return_from_offer (context,
      g_dbus_server_get_client_address (self->priv->dbus_server));

  if (self->priv->open_mode == TP_TESTS_DBUS_TUBE_CHANNEL_OPEN_SECOND)
    really_open_tube (self);
  else if (self->priv->open_mode == TP_TESTS_DBUS_TUBE_CHANNEL_NEVER_OPEN)
    tp_base_channel_close (TP_BASE_CHANNEL (self));
}

static void
dbus_tube_accept (TpSvcChannelTypeDBusTube *chan,
    guint access_control,
    DBusGMethodInvocation *context)
{
  TpTestsDBusTubeChannel *self = (TpTestsDBusTubeChannel *) chan;

  open_tube (self);

  if (self->priv->open_mode == TP_TESTS_DBUS_TUBE_CHANNEL_OPEN_FIRST)
    really_open_tube (self);

  tp_svc_channel_type_dbus_tube_return_from_accept (context,
      g_dbus_server_get_client_address (self->priv->dbus_server));

  if (self->priv->open_mode == TP_TESTS_DBUS_TUBE_CHANNEL_OPEN_SECOND)
    really_open_tube (self);
  else if (self->priv->open_mode == TP_TESTS_DBUS_TUBE_CHANNEL_NEVER_OPEN)
    tp_base_channel_close (TP_BASE_CHANNEL (self));
}

void
tp_tests_dbus_tube_channel_set_open_mode (
    TpTestsDBusTubeChannel *self,
    TpTestsDBusTubeChannelOpenMode open_mode)
{
  self->priv->open_mode = open_mode;
}

static void
dbus_tube_iface_init (gpointer iface,
    gpointer data)
{
  TpSvcChannelTypeDBusTubeClass *klass = iface;

#define IMPLEMENT(x) tp_svc_channel_type_dbus_tube_implement_##x (klass, dbus_tube_##x)
  IMPLEMENT (offer);
  IMPLEMENT (accept);
#undef IMPLEMENT
}

/* Contact DBus Tube */

G_DEFINE_TYPE (TpTestsContactDBusTubeChannel,
    tp_tests_contact_dbus_tube_channel,
    TP_TESTS_TYPE_DBUS_TUBE_CHANNEL)

static void
tp_tests_contact_dbus_tube_channel_init (
    TpTestsContactDBusTubeChannel *self)
{
}

static void
tp_tests_contact_dbus_tube_channel_class_init (
    TpTestsContactDBusTubeChannelClass *klass)
{
  TpBaseChannelClass *base_class = TP_BASE_CHANNEL_CLASS (klass);

  base_class->target_handle_type = TP_HANDLE_TYPE_CONTACT;
}

/* Room DBus Tube */

G_DEFINE_TYPE (TpTestsRoomDBusTubeChannel,
    tp_tests_room_dbus_tube_channel,
    TP_TESTS_TYPE_DBUS_TUBE_CHANNEL)

static void
tp_tests_room_dbus_tube_channel_init (
    TpTestsRoomDBusTubeChannel *self)
{
}

static void
tp_tests_room_dbus_tube_channel_class_init (
    TpTestsRoomDBusTubeChannelClass *klass)
{
  TpBaseChannelClass *base_class = TP_BASE_CHANNEL_CLASS (klass);

  base_class->target_handle_type = TP_HANDLE_TYPE_ROOM;
}
