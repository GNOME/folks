
#include "config.h"

#include "room-list-chan.h"

#include <telepathy-glib/telepathy-glib.h>
#include <telepathy-glib/channel-iface.h>
#include <telepathy-glib/svc-channel.h>

static void room_list_iface_init (gpointer iface,
    gpointer data);

G_DEFINE_TYPE_WITH_CODE (TpTestsRoomListChan, tp_tests_room_list_chan, TP_TYPE_BASE_CHANNEL,
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CHANNEL_TYPE_ROOM_LIST, room_list_iface_init))

enum {
  PROP_SERVER = 1,
  LAST_PROPERTY,
};

/*
enum {
  LAST_SIGNAL
};

static guint signals[LAST_SIGNAL];
*/

struct _TpTestsRoomListChanPriv {
  gchar *server;
  gboolean listing;
};

static void
tp_tests_room_list_chan_get_property (GObject *object,
    guint property_id,
    GValue *value,
    GParamSpec *pspec)
{
  TpTestsRoomListChan *self = TP_TESTS_ROOM_LIST_CHAN (object);

  switch (property_id)
    {
      case PROP_SERVER:
        g_value_set_string (value, self->priv->server);
        break;
      default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
tp_tests_room_list_chan_set_property (GObject *object,
    guint property_id,
    const GValue *value,
    GParamSpec *pspec)
{
  TpTestsRoomListChan *self = TP_TESTS_ROOM_LIST_CHAN (object);

  switch (property_id)
    {
      case PROP_SERVER:
        g_assert (self->priv->server == NULL); /* construct only */
        self->priv->server = g_value_dup_string (value);
        break;
      default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
tp_tests_room_list_chan_constructed (GObject *object)
{
  TpTestsRoomListChan *self = TP_TESTS_ROOM_LIST_CHAN (object);
  void (*chain_up) (GObject *) =
      ((GObjectClass *) tp_tests_room_list_chan_parent_class)->constructed;

  if (chain_up != NULL)
    chain_up (object);

  tp_base_channel_register (TP_BASE_CHANNEL (self));
}

static void
tp_tests_room_list_chan_finalize (GObject *object)
{
  TpTestsRoomListChan *self = TP_TESTS_ROOM_LIST_CHAN (object);
  void (*chain_up) (GObject *) =
      ((GObjectClass *) tp_tests_room_list_chan_parent_class)->finalize;

  g_free (self->priv->server);

  if (chain_up != NULL)
    chain_up (object);
}

static void
fill_immutable_properties (TpBaseChannel *chan,
    GHashTable *properties)
{
  TpBaseChannelClass *klass = TP_BASE_CHANNEL_CLASS (
      tp_tests_room_list_chan_parent_class);

  klass->fill_immutable_properties (chan, properties);

  tp_dbus_properties_mixin_fill_properties_hash (
      G_OBJECT (chan), properties,
      TP_IFACE_CHANNEL_TYPE_ROOM_LIST, "Server",
      NULL);
}

static void
room_list_chan_close (TpBaseChannel *channel)
{
  tp_base_channel_destroyed (channel);
}

static void
tp_tests_room_list_chan_class_init (
    TpTestsRoomListChanClass *klass)
{
  GObjectClass *oclass = G_OBJECT_CLASS (klass);
  TpBaseChannelClass *base_class = TP_BASE_CHANNEL_CLASS (klass);
  GParamSpec *spec;
  static TpDBusPropertiesMixinPropImpl room_list_props[] = {
      { "Server", "server", NULL, },
      { NULL }
  };

  oclass->get_property = tp_tests_room_list_chan_get_property;
  oclass->set_property = tp_tests_room_list_chan_set_property;
  oclass->constructed = tp_tests_room_list_chan_constructed;
  oclass->finalize = tp_tests_room_list_chan_finalize;

  base_class->channel_type = TP_IFACE_CHANNEL_TYPE_ROOM_LIST;
  base_class->target_handle_type = TP_HANDLE_TYPE_NONE;
  base_class->fill_immutable_properties = fill_immutable_properties;
  base_class->close = room_list_chan_close;

  spec = g_param_spec_string ("server", "server",
      "Server",
      "",
      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (oclass, PROP_SERVER, spec);

  tp_dbus_properties_mixin_implement_interface (oclass,
      TP_IFACE_QUARK_CHANNEL_TYPE_ROOM_LIST,
      tp_dbus_properties_mixin_getter_gobject_properties, NULL,
      room_list_props);

  g_type_class_add_private (klass, sizeof (TpTestsRoomListChanPriv));
}

static void
tp_tests_room_list_chan_init (TpTestsRoomListChan *self)
{
  self->priv = G_TYPE_INSTANCE_GET_PRIVATE (self,
      TP_TESTS_TYPE_ROOM_LIST_CHAN, TpTestsRoomListChanPriv);
}

static void
add_room (GPtrArray *rooms)
{
  GHashTable *hash;

  hash = tp_asv_new (
      "handle-name", G_TYPE_STRING, "the handle name",
      "name", G_TYPE_STRING, "the name",
      "description", G_TYPE_STRING, "the description",
      "subject", G_TYPE_STRING, "the subject",
      "members", G_TYPE_UINT, 10,
      "password", G_TYPE_BOOLEAN, TRUE,
      "invite-only", G_TYPE_BOOLEAN, TRUE,
      "room-id", G_TYPE_STRING, "the room id",
      "server", G_TYPE_STRING, "the server",
      NULL);

  g_ptr_array_add (rooms, tp_value_array_build (3,
        G_TYPE_UINT, 0,
        G_TYPE_STRING, TP_IFACE_CHANNEL_TYPE_TEXT,
        TP_HASH_TYPE_STRING_VARIANT_MAP, hash,
        G_TYPE_INVALID));

  g_hash_table_unref (hash);
}

static gboolean
find_rooms (gpointer data)
{
  TpTestsRoomListChan *self = TP_TESTS_ROOM_LIST_CHAN (data);
  GPtrArray *rooms;

  rooms = g_ptr_array_new_with_free_func ((GDestroyNotify) g_value_array_free);

  /* Find 2 rooms */
  add_room (rooms);
  add_room (rooms);
  tp_svc_channel_type_room_list_emit_got_rooms (self, rooms);
  g_ptr_array_set_size (rooms, 0);

  /* Find 1 room */
  add_room (rooms);
  tp_svc_channel_type_room_list_emit_got_rooms (self, rooms);
  g_ptr_array_unref (rooms);

  return FALSE;
}

static void
room_list_list_rooms (TpSvcChannelTypeRoomList *chan,
    DBusGMethodInvocation *context)
{
  TpTestsRoomListChan *self = TP_TESTS_ROOM_LIST_CHAN (chan);

  if (self->priv->listing)
    {
      GError error = { TP_ERROR, TP_ERROR_INVALID_ARGUMENT,
          "Already listing" };

      dbus_g_method_return_error (context, &error);
      return;
    }

  if (!tp_strdiff (self->priv->server, "ListRoomsFail"))
    {
      GError error = { TP_ERROR, TP_ERROR_SERVICE_CONFUSED,
          "Computer says no" };

      dbus_g_method_return_error (context, &error);
      return;
    }

  self->priv->listing = TRUE;
  tp_svc_channel_type_room_list_emit_listing_rooms (self, TRUE);

  g_idle_add (find_rooms, self);

  tp_svc_channel_type_room_list_return_from_list_rooms (context);
}

static void
room_list_iface_init (gpointer iface,
    gpointer data)
{
  TpSvcChannelTypeRoomListClass *klass = iface;

#define IMPLEMENT(x) \
  tp_svc_channel_type_room_list_implement_##x (klass, room_list_##x)
  IMPLEMENT(list_rooms);
#undef IMPLEMENT
}
