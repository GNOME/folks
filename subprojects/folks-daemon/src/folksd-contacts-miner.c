/*
 * Copyright 2022 Corentin Noël <corentin.noel@collabora.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "folksd-contacts-miner.h"
#include "folksd-utils.h"
#include "folksd-config.h"
#if HAS_BLUEZ
#include "folksd-bluez-miner.h"
#endif
#if HAS_EDS
#include "folksd-eds-miner.h"
#endif

struct _EdmContactsMiner
{
  GObject parent_instance;

  GDBusConnection *connection;
  TrackerEndpointDBus *endpoint;
  GCancellable *cancellable;
#if HAS_BLUEZ
  FolksdBluezMiner *bluez_miner;
#endif
#if HAS_EDS
  FolksdEdsMiner *eds_miner;
#endif
};

G_DEFINE_FINAL_TYPE (EdmContactsMiner, edm_contacts_miner, G_TYPE_OBJECT)

enum {
  PROP_0,
  N_PROPS
};

static GParamSpec *properties [N_PROPS];

EdmContactsMiner *
edm_contacts_miner_new (void)
{
  return g_object_new (EDM_TYPE_CONTACTS_MINER, NULL);
}

static void
edm_contacts_miner_dispose (GObject *object)
{
  EdmContactsMiner *self = (EdmContactsMiner *)object;

#if HAS_BLUEZ
  g_clear_object (&self->bluez_miner);
#endif
#if HAS_EDS
  g_clear_object (&self->eds_miner);
#endif

  g_cancellable_cancel (self->cancellable);
  g_clear_object (&self->cancellable);
  g_clear_object (&self->endpoint);
  g_clear_object (&self->connection);

  G_OBJECT_CLASS (edm_contacts_miner_parent_class)->dispose (object);
}

static void
edm_contacts_miner_get_property (GObject    *object,
                                 guint       prop_id,
                                 GValue     *value,
                                 GParamSpec *pspec)
{
  EdmContactsMiner *self = EDM_CONTACTS_MINER (object);

  switch (prop_id)
    {
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
    }
}

static void
edm_contacts_miner_set_property (GObject      *object,
                                 guint         prop_id,
                                 const GValue *value,
                                 GParamSpec   *pspec)
{
  EdmContactsMiner *self = EDM_CONTACTS_MINER (object);

  switch (prop_id)
    {
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
    }
}

static void
edm_contacts_miner_class_init (EdmContactsMinerClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  object_class->dispose = edm_contacts_miner_dispose;
  object_class->get_property = edm_contacts_miner_get_property;
  object_class->set_property = edm_contacts_miner_set_property;
}


gboolean
tracker_dbus_request_name (GDBusConnection  *connection,
                           const gchar      *name,
                           GError          **error)
{
  GError *inner_error = NULL;
  GVariant *reply;
  gint rval;

  reply = g_dbus_connection_call_sync (connection,
                                       "org.freedesktop.DBus",
                                       "/org/freedesktop/DBus",
                                       "org.freedesktop.DBus",
                                       "RequestName",
                                       g_variant_new ("(su)",
                                                      name,
                                                      0x4 /* DBUS_NAME_FLAG_DO_NOT_QUEUE */),
                                       G_VARIANT_TYPE ("(u)"),
                                       0, -1, NULL, &inner_error);
  if (inner_error) {
    g_propagate_prefixed_error (error, inner_error,
                                "Could not acquire name:'%s'. ",
                                name);
    return FALSE;
  }

  g_variant_get (reply, "(u)", &rval);
  g_variant_unref (reply);

  if (rval != 1 /* DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER */) {
    g_set_error (error,
                 G_DBUS_ERROR,
                 G_DBUS_ERROR_ADDRESS_IN_USE,
                 "D-Bus service name:'%s' is already taken, "
                 "perhaps the application is already running?",
                 name);
    return FALSE;
  }

  return TRUE;
}


static void
edm_contacts_miner_init (EdmContactsMiner *self)
{
  g_autoptr(GError) error = NULL;
  g_autoptr(GFile) store = NULL;
  g_autoptr(GFile) ontology = NULL;
  g_autoptr(TrackerSparqlConnection) sparql_conn = NULL;

  self->cancellable = g_cancellable_new ();

  self->connection = g_bus_get_sync (TRACKER_IPC_BUS, self->cancellable, &error);
  if (error) {
    g_critical ("Could not create DBus connection: %s", error->message);
    return;
  }

  store = g_file_new_build_filename (g_get_user_cache_dir (), "folksd", NULL);
  ontology = tracker_sparql_get_ontology_nepomuk ();
  sparql_conn = tracker_sparql_connection_new (TRACKER_SPARQL_CONNECTION_FLAGS_NONE,
                                               store,
                                               ontology,
                                               self->cancellable,
                                               &error);
  if (!sparql_conn) {
    g_critical ("Unable to create SPARQL connection: %s", error->message);
    return;
  }

  self->endpoint = tracker_endpoint_dbus_new (sparql_conn,
                                              self->connection,
                                              NULL,
                                              self->cancellable,
                                              &error);
  if (!self->endpoint) {
    g_critical ("Unable to create endpoint: %s", error->message);
    return;
  }

  if (!tracker_dbus_request_name (self->connection, "org.freedesktop.Tracker3.Miner.Folks", &error)) {
    g_critical ("Unable to own name: %s", error->message);
    return;
  }

#if HAS_BLUEZ
  self->bluez_miner = folksd_bluez_miner_new (self->endpoint);
#endif
#if HAS_EDS
  self->eds_miner = folksd_eds_miner_new (self->endpoint);
#endif
}

