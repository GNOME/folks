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

#include <gio/gio.h>
#include <libtracker-sparql/tracker-sparql.h>

#include "folks-persona-store.h"
#include "folks-persona-store-priv.h"
#include "folks-persona.h"
#include "folks-persona-priv.h"
#include "folks-enums.h"

struct _FolksPersonaStore
{
  GObject parent_instance;

  GPtrArray *personas;
  TrackerSparqlConnection *connection;
  char *addressbook_urn;
  char *title;
  FolksPersonaStorePreloadFlags preload_flags;
};


static void folks_persona_store_list_model_iface_init (GListModelInterface *iface);

G_DEFINE_FINAL_TYPE_WITH_CODE (FolksPersonaStore, folks_persona_store, G_TYPE_OBJECT,
                               G_IMPLEMENT_INTERFACE (G_TYPE_LIST_MODEL,
                                 folks_persona_store_list_model_iface_init))

enum {
  PROP_0,
  PROP_TITLE,
  PROP_PRELOAD_FLAGS,
  N_PROPS
};

static GParamSpec *properties [N_PROPS];

#define FOLKS_PERSONA_STORE_PRELOAD_FLAGS_NUMBER 18

struct FolksPreloadArg {
  const char *variable;
  const char *request;
};

static const struct FolksPreloadArg preload_args[FOLKS_PERSONA_STORE_PRELOAD_FLAGS_NUMBER] = {
    {" ?nickname", "OPTIONAL { ?c nco:nickname ?nickname . } ."},
    {" ?alias", "OPTIONAL { ?c nco:nickname ?alias . } ."},
    {" ?fullname", "OPTIONAL { ?c nco:fullname ?fullname . } ."},
    {" ?structured_name", "OPTIONAL { ?c nco:nickname ?structured_name . } ."},
    {" ?avatar", "OPTIONAL { ?c nco:nickname ?avatar . } ."},
    {" ?birthday", "OPTIONAL { ?c nco:nickname ?birthday . } ."},
    {" ?emails", "OPTIONAL { ?c nco:nickname ?emails . } ."},
    {" ?extended_fields", "OPTIONAL { ?c nco:nickname ?extended_fields . } ."},
    {" ?is_favourite", "OPTIONAL { ?c nco:nickname ?is_favourite . } ."},
    {" ?gender", "OPTIONAL { ?c nco:nickname ?gender . } ."},
    {" ?groups", "OPTIONAL { ?c nco:nickname ?groups . } ."},
    {" ?im_addresses", "OPTIONAL { ?c nco:nickname ?im_addresses . } ."},
    {" ?location", "OPTIONAL { ?c nco:nickname ?location . } ."},
    {" ?notes", "OPTIONAL { ?c nco:nickname ?notes . } ."},
    {" ?phone_numbers", "OPTIONAL { ?c nco:hasPhoneNumber ?phone_numbers . } ."},
    {" ?postal_addresses", "OPTIONAL { ?c nco:nickname ?postal_addresses . } ."},
    {" ?roles", "OPTIONAL { ?c nco:nickname ?roles . } ."},
    {" ?urls", "OPTIONAL { ?c nco:nickname ?urls . } ."},
};

FolksPersonaStore *
folks_persona_store_new (TrackerSparqlConnection *connection,
                         const char *addressbook_urn,
                         const char *title)
{
  FolksPersonaStore *self = g_object_new (FOLKS_TYPE_PERSONA_STORE, "title", title, NULL);
  self->connection = g_object_ref (connection);
  self->addressbook_urn = g_strdup (addressbook_urn);
  return self;
}

static void
folks_persona_store_finalize (GObject *object)
{
  FolksPersonaStore *self = (FolksPersonaStore *)object;

  g_clear_object (&self->connection);
  g_clear_pointer (&self->addressbook_urn, g_free);
  g_clear_pointer (&self->title, g_free);

  G_OBJECT_CLASS (folks_persona_store_parent_class)->finalize (object);
}

static void
folks_persona_store_get_property (GObject    *object,
                                  guint       prop_id,
                                  GValue     *value,
                                  GParamSpec *pspec)
{
  FolksPersonaStore *self = FOLKS_PERSONA_STORE (object);

  switch (prop_id)
    {
    case PROP_TITLE:
      g_value_set_string (value, self->title);
      break;
    case PROP_PRELOAD_FLAGS:
      g_value_set_flags (value, self->preload_flags);
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
    }
}

static void
folks_persona_store_set_property (GObject      *object,
                                  guint         prop_id,
                                  const GValue *value,
                                  GParamSpec   *pspec)
{
  FolksPersonaStore *self = FOLKS_PERSONA_STORE (object);

  switch (prop_id)
    {
    case PROP_TITLE:
      self->title = g_value_dup_string (value);
      break;
    case PROP_PRELOAD_FLAGS:
      self->preload_flags = g_value_get_flags (value);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
    }
}

static void
folks_persona_store_class_init (FolksPersonaStoreClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  object_class->finalize = folks_persona_store_finalize;
  object_class->get_property = folks_persona_store_get_property;
  object_class->set_property = folks_persona_store_set_property;


  properties[PROP_TITLE] =
    g_param_spec_string ("title", NULL, NULL,
                         NULL  /* default value */,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY);

  properties[PROP_PRELOAD_FLAGS] =
    g_param_spec_flags ("preload-flags", NULL, NULL,
                        FOLKS_TYPE_PERSONA_STORE_PRELOAD_FLAGS,
                        FOLKS_PERSONA_STORE_PRELOAD_NICKNAME,
                        G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  g_object_class_install_properties (object_class,
                                     N_PROPS,
                                     properties);
}

static GType
folks_persona_store_get_item_type (GListModel *list)
{
  return FOLKS_TYPE_PERSONA;
}

static guint
folks_persona_store_get_n_items (GListModel *list)
{
  FolksPersonaStore *self = FOLKS_PERSONA_STORE (list);

  g_assert (self->personas);

  return self->personas->len;
}

static gpointer
folks_persona_store_get_item (GListModel *list,
                              guint       position)
{
  FolksPersonaStore *self = FOLKS_PERSONA_STORE (list);

  g_assert (self->personas);

  if (position >= self->personas->len)
    return NULL;

  return g_object_ref (g_ptr_array_index (self->personas, position));
}

static void
folks_persona_store_list_model_iface_init (GListModelInterface *iface)
{
  iface->get_item_type = folks_persona_store_get_item_type;
  iface->get_n_items = folks_persona_store_get_n_items;
  iface->get_item = folks_persona_store_get_item;
}

static void
folks_persona_store_init (FolksPersonaStore *self)
{
  self->personas = g_ptr_array_new_with_free_func (g_object_unref);
  self->preload_flags = FOLKS_PERSONA_STORE_PRELOAD_NICKNAME | FOLKS_PERSONA_STORE_PRELOAD_FULLNAME | FOLKS_PERSONA_STORE_PRELOAD_PHONE_NUMBERS;
}

static void
load_query_preload_args (FolksPersonaStorePreloadFlags   preload_flags,
                         char                          **query,
                         char                          **req)
{
  // Number of FolksPersonaStorePreloadFlags elements + 1
  const char *query_parts[FOLKS_PERSONA_STORE_PRELOAD_FULLNAME + 1] = { NULL, };
  const char *req_parts[FOLKS_PERSONA_STORE_PRELOAD_FULLNAME + 1] = { NULL, };
  int index = 0;

  for (int i = 0; i < FOLKS_PERSONA_STORE_PRELOAD_FLAGS_NUMBER; i++) {
    if (preload_flags & (1ull << i)) {
      query_parts[index] = preload_args[i].variable;
      req_parts[index] = preload_args[i].request;
      index++;
    }
  }

  if (index > 0) {
    *query = g_strjoinv (NULL, (char **)query_parts);
    *req = g_strjoinv (NULL, (char **)req_parts);
  } else {
    *query = g_strdup ("");
    *req = g_strdup ("");
  }
}

static gboolean
find_persona_by_index (gconstpointer a,
                       gconstpointer b)
{
  FolksPersona *persona = (FolksPersona *) a;
  const char *urn_to_find = b;

  return g_strcmp0 (folks_persona_get_urn (persona), urn_to_find) == 0;
}

static void
load_persona_store_task (GTask         *task,
                         gpointer       source_object,
                         gpointer       task_data,
                         GCancellable  *cancellable)
{
  FolksPersonaStore *self = source_object;
  g_autoptr (GError) error = NULL;
  g_autoptr (TrackerSparqlCursor) cursor = NULL;
  g_autoptr (TrackerSparqlStatement) stmt = NULL;
  g_autofree char *query = NULL;
  g_autofree char *vars = NULL;
  g_autofree char *req = NULL;

  g_assert (FOLKS_IS_PERSONA_STORE (self));

  load_query_preload_args(self->preload_flags, &vars, &req);
  query = g_strdup_printf ("SELECT ?c%s { ~urn nco:containsContact ?c . %s }", vars, req);
  stmt = tracker_sparql_connection_query_statement (self->connection,
                                                    query,
                                                    NULL,
                                                    &error);

  if (!stmt) {
    g_task_return_new_error (task,
                             G_IO_ERROR,
                             G_IO_ERROR_FAILED,
                             "Couldn't create a prepared statement: '%s'",
                             error->message);
    return;
  }

  tracker_sparql_statement_bind_string (stmt, "urn", self->addressbook_urn);

  cursor = tracker_sparql_statement_execute (stmt, NULL, &error);
  if (!cursor) {
    g_task_return_new_error (task,
                             G_IO_ERROR,
                             G_IO_ERROR_FAILED,
                             "Couldn't execute query: '%s'",
                             error->message);
    return;
  }

  while (tracker_sparql_cursor_next (cursor, NULL, &error)) {
    FolksPersona *persona;
    const char *persona_urn = tracker_sparql_cursor_get_string (cursor, 0, NULL);
    guint persona_index;
    if (g_ptr_array_find_with_equal_func (self->personas, persona_urn, find_persona_by_index, &persona_index)) {
      persona = g_ptr_array_index (self->personas, persona_index);
    } else {
      persona = folks_persona_new (cursor);
      g_ptr_array_add (self->personas, persona);
    }
  }

  tracker_sparql_cursor_close (cursor);

  if (error) {
    g_task_return_error (task, g_steal_pointer (&error));
  } else {
    g_task_return_boolean (task, TRUE);
  }
}

/* Public */

/**
 * folks_persona_store_load:
 * @self: a #FolksPersonaStore
 * @cancellable: optional #GCancellable object
 * @callback: a #GAsyncReadyCallback to call when the load ended
 * @user_data: data to pass to the @callback
 *
 * Starts a connection with the persona store and retrieve the personas.
 *
 * When the operation is finished, @callback will be called. You can then call
 * folks_persona_store_load_finish() to get the result of the operation.
 */
void
folks_persona_store_load (FolksPersonaStore   *self,
                          GCancellable        *cancellable,
                          GAsyncReadyCallback  callback,
                          gpointer             user_data)
{
  g_autoptr(GTask) task = NULL;

  g_return_if_fail (FOLKS_IS_PERSONA_STORE (self));

  task = g_task_new (self, cancellable, callback, user_data);
  g_task_set_source_tag (task, folks_persona_store_load);
  g_task_run_in_thread (task, load_persona_store_task);
}

/**
 * folks_persona_store_load_finish:
 * @self: a #FolksPersonaStore
 * @result: a #GAsyncResult
 * @error: a #GError
 *
 * Get the result of the operation started with folks_persona_store_load().
 *
 * Returns: %TRUE if the persona store is successfully loaded, %FALSE otherwise
 * and @error is set.
 */
gboolean
folks_persona_store_load_finish (FolksPersonaStore  *self,
                                 GAsyncResult       *result,
                                 GError            **error)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA_STORE (self), FALSE);
  g_return_val_if_fail (g_task_is_valid (result, self), FALSE);

  return g_task_propagate_boolean (G_TASK (result), error);
}

void
folks_persona_store_set_preload_flags (FolksPersonaStore             *self,
                                       FolksPersonaStorePreloadFlags  preload_flags)
{
  g_return_if_fail (FOLKS_IS_PERSONA_STORE (self));

  if (self->preload_flags == preload_flags)
    return;

  self->preload_flags = preload_flags;
  g_object_notify_by_pspec (G_OBJECT (self), properties[PROP_PRELOAD_FLAGS]);
}

FolksPersonaStorePreloadFlags
folks_persona_store_get_preload_flags (FolksPersonaStore *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA_STORE (self), 0ull);

  return self->preload_flags;
}
