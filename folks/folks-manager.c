/*
 * SPDX-License-Identifier: LGPL-2.1-or-later
 *
 * Copyright 2023 Collabora, Ltd.
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <libtracker-sparql/tracker-sparql.h>

#include "folks-persona-store-priv.h"
#include "folks-manager.h"

struct _FolksManager
{
  GObject parent_instance;

  GHashTable *tracker_connections;
  GPtrArray *persona_stores;
};

static void folks_manager_initable_iface_init (GInitableIface *iface);
static void folks_manager_initable_async_iface_init (GAsyncInitableIface *iface);
static void folks_manager_list_model_iface_init (GListModelInterface *iface);

G_DEFINE_FINAL_TYPE_WITH_CODE (FolksManager, folks_manager, G_TYPE_OBJECT,
                               G_IMPLEMENT_INTERFACE (G_TYPE_INITABLE,
                                 folks_manager_initable_iface_init)
                               G_IMPLEMENT_INTERFACE (G_TYPE_ASYNC_INITABLE,
                                 folks_manager_initable_async_iface_init)
                               G_IMPLEMENT_INTERFACE (G_TYPE_LIST_MODEL,
                                 folks_manager_list_model_iface_init))

enum {
  PROP_0,
  N_PROPS
};

static GParamSpec *properties [N_PROPS];

FolksManager *
folks_manager_new_sync (GCancellable  *cancellable,
                        GError       **error)
{
  g_return_val_if_fail (error == NULL || *error == NULL, NULL);

  return g_initable_new (FOLKS_TYPE_MANAGER, cancellable, error, NULL);
}

void
folks_manager_new (int                  io_priority,
                   GCancellable        *cancellable,
                   GAsyncReadyCallback  callback,
                   gpointer             user_data)
{
  return g_async_initable_new_async (FOLKS_TYPE_MANAGER, io_priority, cancellable, callback, user_data, NULL);
}

FolksManager *
folks_manager_new_finish (GAsyncResult  *res,
                          GError       **error)
{
  GObject *object;
  GObject *source_object;

  g_return_val_if_fail (G_IS_ASYNC_RESULT (res), NULL);
  g_return_val_if_fail (error == NULL || *error == NULL, NULL);

  source_object = g_async_result_get_source_object (res);
  g_assert (source_object != NULL);
  object = g_async_initable_new_finish (G_ASYNC_INITABLE (source_object),
                                        res,
                                        error);
  g_object_unref (source_object);
  if (object != NULL)
    return FOLKS_MANAGER (object);
  else
    return NULL;
}

static void
folks_manager_finalize (GObject *object)
{
  FolksManager *self = (FolksManager *)object;

  g_clear_pointer (&self->persona_stores, g_ptr_array_unref);
  g_clear_pointer (&self->tracker_connections, g_hash_table_unref);

  G_OBJECT_CLASS (folks_manager_parent_class)->finalize (object);
}

static void
folks_manager_get_property (GObject    *object,
                            guint       prop_id,
                            GValue     *value,
                            GParamSpec *pspec)
{
  FolksManager *self = FOLKS_MANAGER (object);

  switch (prop_id)
    {
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
    }
}

static void
folks_manager_set_property (GObject      *object,
                            guint         prop_id,
                            const GValue *value,
                            GParamSpec   *pspec)
{
  FolksManager *self = FOLKS_MANAGER (object);

  switch (prop_id)
    {
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
    }
}

static void
folks_manager_class_init (FolksManagerClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  object_class->finalize = folks_manager_finalize;
  object_class->get_property = folks_manager_get_property;
  object_class->set_property = folks_manager_set_property;
}

static gboolean
folks_manager_initable_init (GInitable     *initable,
                             GCancellable  *cancellable,
                             GError       **error)
{
  FolksManager *self = (FolksManager *)initable;
  g_autoptr(TrackerSparqlConnection) connection = NULL;
  g_autoptr(TrackerSparqlCursor) cursor = NULL;

  connection = tracker_sparql_connection_bus_new ("org.freedesktop.Tracker3.Miner.Folks", NULL, NULL, error);
  if (!connection)
    return FALSE;

  cursor = tracker_sparql_connection_query (connection,
                                            "SELECT ?addressbook ?addressbookName WHERE { ?addressbook a nco:ContactList  . "
                                              "OPTIONAL { "
                                                "?addressbook nie:title ?addressbookName ."
                                                "} }",
                                            cancellable,
                                            error);
  if (!cursor) {
    tracker_sparql_connection_close (connection);
    return FALSE;
  }

  g_hash_table_insert (self->tracker_connections, "org.freedesktop.Tracker3.Miner.Folks", g_object_ref (connection));

  while (tracker_sparql_cursor_next (cursor, cancellable, error)) {
    g_autoptr(FolksPersonaStore) persona_store = NULL;
    const char *addressbook_urn;
    const char *title;

    addressbook_urn = tracker_sparql_cursor_get_string (cursor, 0, NULL);
    title = tracker_sparql_cursor_get_string (cursor, 0, NULL);
    persona_store = folks_persona_store_new (connection, addressbook_urn, title);
    g_ptr_array_add (self->persona_stores, g_steal_pointer (&persona_store));
    //g_list_model_items_changed (G_LIST_MODEL (self), self->persona_stores->len - 1, 0, 1);
  }

  tracker_sparql_cursor_close (cursor);
  if (error && *error != NULL)
    return FALSE;

  return TRUE;
}

static GType
folks_manager_get_item_type (GListModel *list)
{
  return FOLKS_TYPE_PERSONA_STORE;
}

static guint
folks_manager_get_n_items (GListModel *list)
{
  FolksManager *self = FOLKS_MANAGER (list);

  g_assert (self->persona_stores);

  return self->persona_stores->len;
}

static gpointer
folks_manager_get_item (GListModel *list,
                        guint       position)
{
  FolksManager *self = FOLKS_MANAGER (list);

  g_assert (self->persona_stores);

  if (position >= self->persona_stores->len)
    return NULL;

  return g_object_ref (g_ptr_array_index (self->persona_stores, position));
}

static void
folks_manager_initable_iface_init (GInitableIface *iface)
{
  iface->init = folks_manager_initable_init;
}

static void
folks_manager_initable_async_iface_init (GAsyncInitableIface *iface)
{
  // Calls GInitable in a thread by default
}

static void
folks_manager_list_model_iface_init (GListModelInterface *iface)
{
  iface->get_item_type = folks_manager_get_item_type;
  iface->get_n_items = folks_manager_get_n_items;
  iface->get_item = folks_manager_get_item;
}

static void
folks_manager_init (FolksManager *self)
{
  self->tracker_connections = g_hash_table_new_full (g_str_hash, g_str_equal, NULL, g_object_unref);
  self->persona_stores = g_ptr_array_new_with_free_func (g_object_unref);
}
