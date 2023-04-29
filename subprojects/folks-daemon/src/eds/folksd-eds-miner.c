#include "folksd-eds-miner.h"

#include <gio/gio.h>
#include <libedataserver/libedataserver.h>
#include <libebook/libebook.h>

#include "missing-autocleanups/missing-autocleanups.h"
#include "folksd-utils.h"

struct _FolksdEdsMiner
{
  GObject parent_instance;

  TrackerEndpointDBus *endpoint;
  GCancellable *cancellable;
  ESourceRegistry *source_registry;
  ESourceRegistryWatcher *watcher;
  GPtrArray *opened_client_views;
};

G_DEFINE_FINAL_TYPE (FolksdEdsMiner, folksd_eds_miner, G_TYPE_OBJECT)

enum {
  PROP_TRACKER_ENDPOINT = 1,
  N_PROPS
};

static GParamSpec *properties [N_PROPS];

FolksdEdsMiner *
folksd_eds_miner_new (TrackerEndpointDBus *endpoint)
{
  return g_object_new (FOLKSD_TYPE_EDS_MINER, "endpoint", endpoint, NULL);
}

static void
folksd_create_contact_resource (TrackerResource *addressbook,
                                EContact *contact)
{
  g_autoptr(EContactName) name = NULL;
  g_autofree char *full_name = NULL;
  g_autofree char *uri = NULL;
  TrackerResource *resource;
  const char *uid;
  g_autofree char *affiliation_uri = NULL;
  TrackerResource *affiliation;
  GList *emails;
  GList *tels;

  g_assert(addressbook != NULL);
  g_assert(contact != NULL);

  name = e_contact_get (contact, E_CONTACT_NAME);
  if (!name) {
    g_warning ("No name field!");
    return;
  }

  full_name = e_contact_name_to_string (name);
  uri = tracker_sparql_escape_uri_printf ("%s:contact:%s", tracker_resource_get_identifier (addressbook), full_name);

  resource = tracker_resource_new (uri);
  tracker_resource_set_uri (resource, "rdf:type", "nco:PersonContact");

  uid = e_contact_get_const (contact, E_CONTACT_UID);
  tracker_resource_set_string (resource, "nco:contactUID", uid);

  tracker_resource_set_string (resource, "nco:fullname", full_name);
  if (name->given)
    tracker_resource_set_string (resource, "nco:nameGiven", name->given);
  if (name->family)
    tracker_resource_set_string (resource, "nco:nameFamily", name->family);
  if (name->additional)
    tracker_resource_set_string (resource, "nco:nameAdditional", name->additional);
  if (name->prefixes)
    tracker_resource_set_string (resource, "nco:nameHonorificPrefix", name->prefixes);
  if (name->suffixes)
    tracker_resource_set_string (resource, "nco:nameHonorificSuffix", name->suffixes);

  affiliation_uri = g_strdup_printf ("%s:affiliation", uri);
  affiliation = tracker_resource_new (affiliation_uri);
  tracker_resource_set_uri (affiliation, "rdf:type", "nco:Role");
  emails = e_contact_get (contact, E_CONTACT_EMAIL);
  for (GList *l = emails; l != NULL; l = l->next) {
    g_autofree char *email = g_strdup_printf ("<mailto:%s>", (const char*) l->data);
    tracker_resource_set_string (affiliation, "nco:hasEmailAddress", email);
  }

  g_clear_pointer (&emails, e_contact_attr_list_free);
  tels = e_contact_get (contact, E_CONTACT_TEL);
  for (GList *l = tels; l != NULL; l = l->next) {
    g_autofree char *tel = g_strdup_printf ("<tel:%s>", (const char*) l->data);
    tracker_resource_set_string (affiliation, "nco:hasPhoneNumber", tel);
  }

  g_clear_pointer (&tels, e_contact_attr_list_free);
  tracker_resource_add_take_relation(resource, "nco:hasAffiliation", g_steal_pointer (&affiliation));

  tracker_resource_add_take_relation(addressbook, "nco:containsContact", g_steal_pointer (&resource));
}

static void
on_book_objects_added (FolksdEdsMiner *self,
                       GSList *contacts,
                       EBookClientView *client_view)
{
  g_autoptr(EBookClient) client = e_book_client_view_ref_client (client_view);
  ESource *source = e_client_get_source (E_CLIENT(client));
  g_autoptr(TrackerResource) addressbook_resource = folksd_utils_create_addressbook (e_source_get_uid (source), e_source_get_display_name (source));
  TrackerSparqlConnection *connection;
  g_autoptr(TrackerBatch) batch = NULL;
  g_autoptr(GError) error = NULL;

  for (GSList *l = contacts; l != NULL; l = l->next)
    {
      EContact* contact = l->data;
      folksd_create_contact_resource (addressbook_resource, contact);
    }

  connection = tracker_endpoint_get_sparql_connection (TRACKER_ENDPOINT (self->endpoint));
  batch = tracker_sparql_connection_create_batch (connection);
  tracker_batch_add_resource (batch, NULL, addressbook_resource);

  if (!tracker_batch_execute (batch, NULL, &error)) {
    g_critical ("Couldn't insert batch of resources: %s", error->message);
    return;
  }
}

static void
on_book_objects_removed (G_GNUC_UNUSED FolksdEdsMiner *self,
                         GSList *contact_ids,
                         G_GNUC_UNUSED EBookClientView *client_view)
{
  for (GSList *l = contact_ids; l != NULL; l = l->next)
    {
      G_GNUC_UNUSED char* contact_id = l->data;
    }
}

static void
on_book_objects_modified (G_GNUC_UNUSED FolksdEdsMiner *self,
                          GSList *contacts,
                          G_GNUC_UNUSED EBookClientView *client_view)
{
  for (GSList *l = contacts; l != NULL; l = l->next)
    {
      G_GNUC_UNUSED EContact* contact = l->data;
    }
}

static void
on_book_client_view (GObject *source_object,
                     GAsyncResult *res,
                     gpointer user_data)
{
  FolksdEdsMiner *self = user_data;
  g_autoptr(GError) error = NULL;
  g_autoptr(EBookClientView) view = NULL;

  if (!e_book_client_get_view_finish (E_BOOK_CLIENT (source_object),
                                      res,
                                      &view,
                                      &error))
    {
      g_critical ("Unable to query book client view: %s", error->message);
      return;
    }

  g_signal_connect_object (view, "objects-added", G_CALLBACK (on_book_objects_added), self, G_CONNECT_SWAPPED);
  g_signal_connect_object (view, "objects-removed", G_CALLBACK (on_book_objects_removed), self, G_CONNECT_SWAPPED);
  g_signal_connect_object (view, "objects-modified", G_CALLBACK (on_book_objects_modified), self, G_CONNECT_SWAPPED);

  e_book_client_view_start (view, &error);
  g_ptr_array_add (self->opened_client_views, g_steal_pointer (&view));
}

static void
on_book_client_connected (G_GNUC_UNUSED GObject *source_object,
                          GAsyncResult *res,
                          gpointer user_data)
{
  FolksdEdsMiner *self = user_data;
  g_autoptr(EClient) book_client = NULL;
  g_autoptr(GError) error = NULL;

  book_client = e_book_client_connect_finish (res, &error);
  if (!book_client) {
    g_critical ("Unable to open Book client: %s", error->message);
    return;
  }

  e_book_client_get_view (E_BOOK_CLIENT(book_client),
                          "(contains \"x-evolution-any-field\" \"\")",
                          self->cancellable,
                          on_book_client_view,
                          self);
}

static void
on_address_book_appeared (FolksdEdsMiner *self,
                          ESource *source,
                          G_GNUC_UNUSED ESourceRegistryWatcher *watcher)
{
  e_book_client_connect (source,
                         -1,
                         self->cancellable,
                         on_book_client_connected,
                         self);
}

static void
on_address_book_disappeared (G_GNUC_UNUSED FolksdEdsMiner *self,
                             G_GNUC_UNUSED ESource *source,
                             G_GNUC_UNUSED ESourceRegistryWatcher *watcher)
{
}

static void
folksd_eds_miner_finalize (GObject *object)
{
  FolksdEdsMiner *self = (FolksdEdsMiner *)object;

  if (self->cancellable)
    g_cancellable_cancel (self->cancellable);

  if (self->watcher) {
    g_signal_handlers_disconnect_by_func (self->watcher, on_address_book_appeared, self);
    g_signal_handlers_disconnect_by_func (self->watcher, on_address_book_disappeared, self);
  }

  g_clear_object (&self->cancellable);
  g_clear_pointer (&self->opened_client_views, g_ptr_array_unref);
  g_clear_object (&self->watcher);
  g_clear_object (&self->source_registry);
  g_clear_object (&self->endpoint);

  G_OBJECT_CLASS (folksd_eds_miner_parent_class)->finalize (object);
}

static void
folksd_eds_miner_get_property (GObject    *object,
                               guint       prop_id,
                               GValue     *value,
                               GParamSpec *pspec)
{
  FolksdEdsMiner *self = FOLKSD_EDS_MINER (object);

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
folksd_eds_miner_set_property (GObject      *object,
                               guint         prop_id,
                               const GValue *value,
                               GParamSpec   *pspec)
{
  FolksdEdsMiner *self = FOLKSD_EDS_MINER (object);

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
folksd_eds_miner_class_init (FolksdEdsMinerClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  object_class->finalize = folksd_eds_miner_finalize;
  object_class->get_property = folksd_eds_miner_get_property;
  object_class->set_property = folksd_eds_miner_set_property;

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

static void
folksd_eds_miner_init (FolksdEdsMiner *self)
{
  g_autoptr(GError) error = NULL;

  self->cancellable = g_cancellable_new ();
  self->opened_client_views = g_ptr_array_new_with_free_func (g_object_unref);
  self->source_registry = e_source_registry_new_sync (self->cancellable, &error);
  if (G_UNLIKELY (!self->source_registry)) {
    g_debug ("Unable to contact Evolution Data Server: %s", error->message);
    return;
  }

  self->watcher = e_source_registry_watcher_new (self->source_registry, E_SOURCE_EXTENSION_ADDRESS_BOOK);
  g_signal_connect_swapped (self->watcher, "appeared", G_CALLBACK (on_address_book_appeared), self);
  g_signal_connect_swapped (self->watcher, "disappeared", G_CALLBACK (on_address_book_disappeared), self);
  e_source_registry_watcher_reclaim (self->watcher);
}
