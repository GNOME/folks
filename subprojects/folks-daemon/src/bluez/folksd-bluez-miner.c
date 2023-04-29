#include "folksd-bluez-miner.h"

#include <libebook-contacts/libebook-contacts.h>

#include "folksd-bluez-device.h"
#include "folksd-bluez-obex-client.h"
#include "folksd-bluez-device-handler.h"
#include "folksd-utils.h"

struct _FolksdBluezMiner
{
  GObject parent_instance;

  TrackerEndpointDBus *endpoint;
  GCancellable *cancellable;
  GPtrArray *handlers;
  GDBusObjectManager *manager;
  FolksdBluezObexClient1 *obex_client;
};

G_DEFINE_FINAL_TYPE (FolksdBluezMiner, folksd_bluez_miner, G_TYPE_OBJECT)

enum {
  PROP_TRACKER_ENDPOINT = 1,
  N_PROPS
};

static GParamSpec *properties [N_PROPS];

FolksdBluezMiner *
folksd_bluez_miner_new (TrackerEndpointDBus *endpoint)
{
  return g_object_new (FOLKSD_TYPE_BLUEZ_MINER, "endpoint", endpoint, NULL);
}

static void
folksd_bluez_miner_finalize (GObject *object)
{
  FolksdBluezMiner *self = (FolksdBluezMiner *)object;

  if (self->cancellable)
    g_cancellable_cancel (self->cancellable);

  g_clear_object (&self->cancellable);
  g_clear_object (&self->endpoint);
  g_clear_object (&self->obex_client);
  g_clear_object (&self->manager);

  G_OBJECT_CLASS (folksd_bluez_miner_parent_class)->finalize (object);
}

static void
folksd_bluez_miner_get_property (GObject    *object,
                                 guint       prop_id,
                                 GValue     *value,
                                 GParamSpec *pspec)
{
  FolksdBluezMiner *self = FOLKSD_BLUEZ_MINER (object);

  switch (prop_id)
    {
    case PROP_TRACKER_ENDPOINT:
      g_value_set_object (value, self->endpoint);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
    }
}

static void
folksd_bluez_miner_set_property (GObject      *object,
                                 guint         prop_id,
                                 const GValue *value,
                                 GParamSpec   *pspec)
{
  FolksdBluezMiner *self = FOLKSD_BLUEZ_MINER (object);

  switch (prop_id)
    {
    case PROP_TRACKER_ENDPOINT:
      g_assert (!self->endpoint);
      self->endpoint = g_value_dup_object (value);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
    }
}

static void
folksd_bluez_miner_class_init (FolksdBluezMinerClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  object_class->finalize = folksd_bluez_miner_finalize;
  object_class->get_property = folksd_bluez_miner_get_property;
  object_class->set_property = folksd_bluez_miner_set_property;

  properties[PROP_TRACKER_ENDPOINT] =
    g_param_spec_object ("endpoint",
                         "Endpoint",
                         "Tracker DBus Endpoint",
                         TRACKER_TYPE_ENDPOINT_DBUS,
                         G_PARAM_CONSTRUCT_ONLY | G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);

  g_object_class_install_properties (object_class,
                                     N_PROPS,
                                     properties);
}

static gboolean
device_supports_pbap_pse (FolksdBluezDevice1 *device)
{
  g_auto(GStrv) uuids = NULL;

  g_assert (FOLKSD_BLUEZ_IS_DEVICE1 (device));

  uuids = folksd_bluez_device1_dup_uuids (device);
  if (!uuids)
    return FALSE;

  for (int i = 0; uuids[i] != NULL; i++) {
    /* Phonebook Access - PSE (Phone Book Server Equipment).
     * 0x112F is the pse part. */
    if (!g_strcmp0 (uuids[i], "0000112f-0000-1000-8000-00805f9b34fb")) {
      return TRUE;
    }
  }

  return FALSE;
}

static void
on_device_contact_updated (GObject *source_object,
                           GAsyncResult *res,
                           gpointer user_data)
{
  FolksdBluezMiner *self = user_data;
  g_autoptr(GError) error = NULL;
  g_autoptr(GFile) file = NULL;
  g_autoptr(GFileInputStream) istream = NULL;
  g_autoptr(GDataInputStream) dataistream = NULL;
  g_autoptr(GString) vcard_str = NULL;
  g_autoptr(TrackerResource) addressbook_resource = NULL;
  g_autoptr(TrackerBatch) batch = NULL;
  TrackerSparqlConnection *connection;

  file = folksd_bluez_device_handler_update_contacts_finish (FOLKSD_BLUEZ_DEVICE_HANDLER (source_object), res, &error);
  if (!file) {
    g_critical ("Error getting contacts: %s", error->message);
    return;
  }

  istream = g_file_read (file, NULL, &error);
  if (!istream) {
    g_critical ("Error reading file: %s", error->message);
    return;
  }

  addressbook_resource = folksd_utils_create_addressbook ("phone", "Phone Contacts");
  dataistream = g_data_input_stream_new (G_INPUT_STREAM (istream));
  vcard_str = g_string_new (NULL);
  while (TRUE) {
    g_autofree char *line = NULL;

    line = g_data_input_stream_read_line (dataistream, NULL, NULL, &error);
    if (line)
      g_string_append_printf (vcard_str, "%s\n", line);

    if ((!line || !g_ascii_strncasecmp (line, "END:VCARD", sizeof("END:VCARD") - 1)) && vcard_str->len > 0) {
      EVCard *vcard;
      vcard = e_vcard_new_from_string (vcard_str->str);
      e_vcard_dump_structure (vcard);
      g_object_unref (vcard);
      g_string_truncate (vcard_str, 0);
    }

    if (!line)
      break;
  }

  connection = tracker_endpoint_get_sparql_connection (TRACKER_ENDPOINT (self->endpoint));
  batch = tracker_sparql_connection_create_batch (connection);
  tracker_batch_add_resource (batch, NULL, addressbook_resource);

  if (!tracker_batch_execute (batch, NULL, &error)) {
    g_printerr ("Couldn't insert batch of resources: %s", error->message);
    return;
  }

}

static void
on_dbus_object_added (FolksdBluezMiner *self,
                      GDBusObject *object,
                      G_GNUC_UNUSED GDBusObjectManager *manager)
{
  g_autoptr(FolksdBluezDevice1) dev = NULL;
  g_autoptr(FolksdBluezDeviceHandler) handler = NULL;
  const gchar *path;

  dev = folksd_bluez_object_get_device1 (FOLKSD_BLUEZ_OBJECT (object));
  if (!dev)
    return;

  path = g_dbus_object_get_object_path (object);
  g_debug ("Adding device at path ‘%s’.", path);

  if (!folksd_bluez_device1_get_paired (dev)) {
    g_debug ("    Device isn’t paired. Ignoring. Manually pair the device to start downloading contacts.");
    return;
  }

  if (!folksd_bluez_device1_get_connected (dev)) {
    g_debug ("    Device is disconnected. Ignoring.");
    return;
  }

  if (folksd_bluez_device1_get_blocked (dev)) {
    g_debug ("    Device is blocked. Ignoring.");
    return;
  }

  if (!device_supports_pbap_pse (dev)) {
    g_debug ("    Doesn’t support PBAP PSE. Ignoring.");
    return;
  }

  handler = folksd_bluez_device_handler_new (dev, self->obex_client);
  folksd_bluez_device_handler_update_contacts_async (handler,
                                                     folksd_bluez_device_handler_get_cancellable (handler),
                                                     on_device_contact_updated,
                                                     self);


  g_ptr_array_add (self->handlers, g_steal_pointer (&handler));
}

gboolean
hander_matches_device (FolksdBluezDeviceHandler *a,
                       FolksdBluezDevice1 *b)
{
  return folksd_bluez_device_handler_get_device (a) == b;
}

static void
on_dbus_object_removed (FolksdBluezMiner *self,
                        G_GNUC_UNUSED GDBusObject *object,
                        G_GNUC_UNUSED GDBusObjectManager *manager)
{
  g_autoptr(FolksdBluezDevice1) dev = NULL;
  guint index_;

  dev = folksd_bluez_object_get_device1 (FOLKSD_BLUEZ_OBJECT (object));
  if (!dev)
    return;

  if (g_ptr_array_find_with_equal_func (self->handlers,
                                        object,
                                        (GEqualFunc) hander_matches_device,
                                        &index_)) {
    FolksdBluezDeviceHandler *handler = g_ptr_array_index (self->handlers, index_);
    g_cancellable_cancel (folksd_bluez_device_handler_get_cancellable (handler));
    g_ptr_array_remove_index_fast (self->handlers, index_);
  }
}

static void
on_bluez_client_proxy (G_GNUC_UNUSED GObject *source_object,
                       GAsyncResult *res,
                       gpointer user_data)
{
  FolksdBluezMiner *self = user_data;
  g_autoptr(GError) error = NULL;

  self->obex_client = folksd_bluez_obex_client1_proxy_new_for_bus_finish (res, &error);
  if (!self->obex_client) {
    g_critical ("Error connecting to OBEX transfer daemon over D-Bus. Ensure BlueZ and obexd are installed. (%s)", error->message);
    return;
  }

  g_signal_connect_swapped (self->manager, "object-added" , G_CALLBACK(on_dbus_object_added), self);
  g_signal_connect_swapped (self->manager, "object-removed" , G_CALLBACK(on_dbus_object_removed), self);
  g_autolist(GDBusObject) object_list = g_dbus_object_manager_get_objects (self->manager);
  for (GList *l = object_list; l != NULL; l = l->next)
  {
    on_dbus_object_added (self, l->data, self->manager);
  }
}

static void
on_bluez_object_manager (G_GNUC_UNUSED GObject *source_object,
                         GAsyncResult *res,
                         gpointer user_data)
{
  FolksdBluezMiner *self = user_data;
  g_autoptr(GError) error = NULL;

  self->manager = folksd_bluez_object_manager_client_new_for_bus_finish (res, &error);
  if (!self->manager) {
    g_critical ("No BlueZ 5 object manager running, so the BlueZ backend will be inactive. Either your BlueZ installation is too old (only version 5 is supported) or the service can’t be started. (%s)", error->message);
    return;
  }

  folksd_bluez_obex_client1_proxy_new_for_bus (
    G_BUS_TYPE_SESSION,
    G_DBUS_PROXY_FLAGS_DO_NOT_AUTO_START_AT_CONSTRUCTION,
    "org.bluez.obex", "/org/bluez/obex",
    self->cancellable,
    on_bluez_client_proxy,
    self);
}

static void
folksd_bluez_miner_init (FolksdBluezMiner *self)
{
  self->cancellable = g_cancellable_new ();
  self->handlers = g_ptr_array_new_with_free_func (g_object_unref);
  folksd_bluez_object_manager_client_new_for_bus (
    G_BUS_TYPE_SYSTEM,
    G_DBUS_OBJECT_MANAGER_CLIENT_FLAGS_NONE,
    "org.bluez", "/",
    self->cancellable,
    on_bluez_object_manager,
    self);
}
