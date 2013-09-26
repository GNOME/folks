/*
 * simple-channel-dispatcher.c - simple channel dispatcher service.
 *
 * Copyright © 2010 Collabora Ltd.
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#include "config.h"

#include "simple-channel-dispatcher.h"

#include <telepathy-glib/telepathy-glib.h>
#include <telepathy-glib/telepathy-glib-dbus.h>

#include "simple-channel-request.h"
#include "simple-conn.h"

static void channel_dispatcher_iface_init (gpointer, gpointer);

G_DEFINE_TYPE_WITH_CODE (TpTestsSimpleChannelDispatcher,
    tp_tests_simple_channel_dispatcher,
    G_TYPE_OBJECT,
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CHANNEL_DISPATCHER,
        channel_dispatcher_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_DBUS_PROPERTIES,
        tp_dbus_properties_mixin_iface_init)
    )

/* signals */
enum {
  CHANNEL_REQUEST_CREATED,
  LAST_SIGNAL
};

static guint signals[LAST_SIGNAL];

/* TP_IFACE_CHANNEL_DISPATCHER is implied */
static const char *CHANNEL_DISPATCHER_INTERFACES[] = { NULL };

enum
{
  PROP_0,
  PROP_INTERFACES,
  PROP_CONNECTION,
};

struct _TpTestsSimpleChannelDispatcherPrivate
{
  /* To keep things simpler, this CD can only create channels using one
   * connection */
  TpTestsSimpleConnection *conn;

  /* List of reffed TpTestsSimpleChannelRequest */
  GSList *requests;

  /* Used when ensuring a channel to store its handler.
   * If this is set we fake that the channel already exist and re-call
   * HandleChannels() on the handler rather than creating a new channel.
   * This is pretty stupid but good enough for our tests. */
  gchar *old_handler;
};

static gchar *
create_channel_request (TpTestsSimpleChannelDispatcher *self,
    const gchar *account,
    GHashTable *request,
    gint64 user_action_time,
    const gchar *preferred_handler,
    GHashTable *hints_,
    GHashTable **out_immutable_properties)
{
  TpTestsSimpleChannelRequest *chan_request;
  GPtrArray *requests;
  static guint count = 0;
  gchar *path;
  TpDBusDaemon *dbus;
  GHashTable *hints;

  requests = g_ptr_array_sized_new (1);
  g_ptr_array_add (requests, request);

  path = g_strdup_printf ("/Request%u", count++);

  if (hints_ == NULL)
    hints = g_hash_table_new (NULL, NULL);
  else
    hints = g_hash_table_ref (hints_);

  chan_request = tp_tests_simple_channel_request_new (path,
      self->priv->conn, account, user_action_time, preferred_handler, requests,
      hints);

  g_hash_table_unref (hints);

  self->priv->requests = g_slist_append (self->priv->requests, chan_request);

  g_ptr_array_unref (requests);

  dbus = tp_dbus_daemon_dup (NULL);
  g_assert (dbus != NULL);

  tp_dbus_daemon_register_object (dbus, path, chan_request);

  g_object_unref (dbus);

  g_signal_emit (self, signals[CHANNEL_REQUEST_CREATED], 0, chan_request);

  *out_immutable_properties =
      tp_tests_simple_channel_request_dup_immutable_props (chan_request);

  return path;
}

static void
tp_tests_simple_channel_dispatcher_create_channel (
    TpSvcChannelDispatcher *dispatcher,
    const gchar *account,
    GHashTable *request,
    gint64 user_action_time,
    const gchar *preferred_handler,
    GHashTable *hints,
    DBusGMethodInvocation *context)
{
  TpTestsSimpleChannelDispatcher *self = SIMPLE_CHANNEL_DISPATCHER (dispatcher);
  gchar *path;
  GHashTable *immutable_properties;

  tp_clear_pointer (&self->last_request, g_hash_table_unref);
  self->last_request = g_boxed_copy (TP_HASH_TYPE_STRING_VARIANT_MAP, request);
  tp_clear_pointer (&self->last_hints, g_hash_table_unref);
  self->last_hints = g_boxed_copy (TP_HASH_TYPE_STRING_VARIANT_MAP, request);
  self->last_user_action_time = user_action_time;
  g_free (self->last_account);
  self->last_account = g_strdup (account);
  g_free (self->last_preferred_handler);
  self->last_preferred_handler = g_strdup (preferred_handler);

  if (tp_asv_get_boolean (request, "CreateChannelFail", NULL))
    {
      /* Fail to create the channel */
      GError error = { TP_ERROR, TP_ERROR_INVALID_ARGUMENT,
          "Computer says no" };

      dbus_g_method_return_error (context, &error);
      return;
    }

  path = create_channel_request (self, account, request, user_action_time,
      preferred_handler, hints, &immutable_properties);

  if (path == NULL)
    return;

  tp_svc_channel_dispatcher_return_from_create_channel (context,
      path, immutable_properties);

  g_free (path);
  g_hash_table_unref (immutable_properties);
}

static void
tp_tests_simple_channel_dispatcher_ensure_channel (
    TpSvcChannelDispatcher *dispatcher,
    const gchar *account,
    GHashTable *request,
    gint64 user_action_time,
    const gchar *preferred_handler,
    GHashTable *hints,
    DBusGMethodInvocation *context)
{
  TpTestsSimpleChannelDispatcher *self = SIMPLE_CHANNEL_DISPATCHER (dispatcher);
  gchar *path;
  GHashTable *immutable_properties;

  tp_clear_pointer (&self->last_request, g_hash_table_unref);
  self->last_request = g_boxed_copy (TP_HASH_TYPE_STRING_VARIANT_MAP, request);
  tp_clear_pointer (&self->last_hints, g_hash_table_unref);
  self->last_hints = g_boxed_copy (TP_HASH_TYPE_STRING_VARIANT_MAP, request);
  self->last_user_action_time = user_action_time;
  g_free (self->last_account);
  self->last_account = g_strdup (account);
  g_free (self->last_preferred_handler);
  self->last_preferred_handler = g_strdup (preferred_handler);

  if (self->priv->old_handler != NULL)
    {
      /* Pretend that the channel already exists */
      path = create_channel_request (self, account, request, user_action_time,
          self->priv->old_handler, hints, &immutable_properties);
    }
  else
    {
      self->priv->old_handler = g_strdup (preferred_handler);

      path = create_channel_request (self, account, request, user_action_time,
          preferred_handler, hints, &immutable_properties);
    }

  tp_svc_channel_dispatcher_return_from_ensure_channel (context,
      path, immutable_properties);

  g_free (path);
  g_hash_table_unref (immutable_properties);
}

static void
free_not_delegated_error (gpointer data)
{
    g_boxed_free (TP_STRUCT_TYPE_NOT_DELEGATED_ERROR, data);
}


static void
tp_tests_simple_channel_dispatcher_delegate_channels (
    TpSvcChannelDispatcher *dispatcher,
    const GPtrArray *channels,
    gint64 user_action_time,
    const gchar *preferred_handler,
    DBusGMethodInvocation *context)
{
  TpTestsSimpleChannelDispatcher *self = (TpTestsSimpleChannelDispatcher *)
    dispatcher;
  GPtrArray *delegated;
  GHashTable *not_delegated;
  guint i;

  delegated = g_ptr_array_new ();
  not_delegated = g_hash_table_new_full (g_str_hash, g_str_equal,
      NULL, free_not_delegated_error);

  for (i = 0; i < channels->len; i++)
    {
      gpointer chan_path = g_ptr_array_index (channels, i);
      GValueArray *v;

      if (!self->refuse_delegate)
        {
          g_ptr_array_add (delegated, chan_path);
          continue;
        }

      v = tp_value_array_build (2,
        G_TYPE_STRING, TP_ERROR_STR_BUSY,
        G_TYPE_STRING, "Nah!",
        G_TYPE_INVALID);

      g_hash_table_insert (not_delegated, chan_path, v);
    }

  tp_svc_channel_dispatcher_return_from_delegate_channels (context, delegated,
      not_delegated);

  g_ptr_array_unref  (delegated);
  g_hash_table_unref (not_delegated);
}

static void
tp_tests_simple_channel_dispatcher_present_channel (
    TpSvcChannelDispatcher *dispatcher,
    const gchar *channel,
    gint64 user_action_time,
    DBusGMethodInvocation *context)
{
  tp_svc_channel_dispatcher_return_from_present_channel (context);
}

static void
channel_dispatcher_iface_init (gpointer klass,
    gpointer unused G_GNUC_UNUSED)
{
#define IMPLEMENT(x) tp_svc_channel_dispatcher_implement_##x (\
  klass, tp_tests_simple_channel_dispatcher_##x)
  IMPLEMENT (create_channel);
  IMPLEMENT (ensure_channel);
  IMPLEMENT (delegate_channels);
  IMPLEMENT (present_channel);
#undef IMPLEMENT
}


static void
tp_tests_simple_channel_dispatcher_init (TpTestsSimpleChannelDispatcher *self)
{
  self->priv = G_TYPE_INSTANCE_GET_PRIVATE (self,
      TP_TESTS_TYPE_SIMPLE_CHANNEL_DISPATCHER,
      TpTestsSimpleChannelDispatcherPrivate);
}

static void
tp_tests_simple_channel_dispatcher_get_property (GObject *object,
              guint property_id,
              GValue *value,
              GParamSpec *spec)
{
  switch (property_id) {
    case PROP_INTERFACES:
      g_value_set_boxed (value, CHANNEL_DISPATCHER_INTERFACES);
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, spec);
      break;
  }
}

static void
tp_tests_simple_channel_dispatcher_set_property (GObject *object,
              guint property_id,
              const GValue *value,
              GParamSpec *spec)
{
  TpTestsSimpleChannelDispatcher *self = SIMPLE_CHANNEL_DISPATCHER (object);

  switch (property_id) {
    case PROP_CONNECTION:
      self->priv->conn = g_value_dup_object (value);
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, spec);
      break;
  }
}

static void
tp_tests_simple_channel_dispatcher_dispose (GObject *object)
{
  TpTestsSimpleChannelDispatcher *self = SIMPLE_CHANNEL_DISPATCHER (object);

  tp_clear_object (&self->priv->conn);

  g_slist_foreach (self->priv->requests, (GFunc) g_object_unref, NULL);
  g_slist_free (self->priv->requests);

  g_free (self->priv->old_handler);

  if (G_OBJECT_CLASS (tp_tests_simple_channel_dispatcher_parent_class)->dispose != NULL)
    G_OBJECT_CLASS (tp_tests_simple_channel_dispatcher_parent_class)->dispose (object);
}

static void
tp_tests_simple_channel_dispatcher_class_init (
    TpTestsSimpleChannelDispatcherClass *klass)
{
  GObjectClass *object_class = (GObjectClass *) klass;
  GParamSpec *param_spec;

  static TpDBusPropertiesMixinPropImpl am_props[] = {
        { "Interfaces", "interfaces", NULL },
        { NULL }
  };

  static TpDBusPropertiesMixinIfaceImpl prop_interfaces[] = {
        { TP_IFACE_CHANNEL_DISPATCHER,
          tp_dbus_properties_mixin_getter_gobject_properties,
          NULL,
          am_props
        },
        { NULL },
  };

  g_type_class_add_private (klass, sizeof (TpTestsSimpleChannelDispatcherPrivate));
  object_class->get_property = tp_tests_simple_channel_dispatcher_get_property;
  object_class->set_property = tp_tests_simple_channel_dispatcher_set_property;

  object_class->dispose = tp_tests_simple_channel_dispatcher_dispose;

  param_spec = g_param_spec_boxed ("interfaces", "Extra D-Bus interfaces",
      "In this case we only implement ChannelDispatcher, so none.",
      G_TYPE_STRV,
      G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_INTERFACES, param_spec);

  param_spec = g_param_spec_object ("connection", "TpTestsSimpleConnection",
      "connection to use when creating channels",
      TP_TESTS_TYPE_SIMPLE_CONNECTION,
      G_PARAM_WRITABLE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_CONNECTION, param_spec);

  /* Fired when we create a new channel request object. This can be used in
   * test to track the progression of a request. */
  signals[CHANNEL_REQUEST_CREATED] = g_signal_new ("channel-request-created",
      G_TYPE_FROM_CLASS (object_class),
      G_SIGNAL_RUN_LAST,
      0, NULL, NULL, NULL,
      G_TYPE_NONE, 1, TP_TESTS_TYPE_SIMPLE_CHANNEL_REQUEST);

  klass->dbus_props_class.interfaces = prop_interfaces;
  tp_dbus_properties_mixin_class_init (object_class,
      G_STRUCT_OFFSET (TpTestsSimpleChannelDispatcherClass, dbus_props_class));
}
