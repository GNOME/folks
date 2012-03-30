/*
 * Copyright (C) 2007-2010 Collabora Ltd.
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
 *
 * Authors:
 *       Travis Reitter <travis.reitter@collabora.co.uk>
 *       Xavier Claessens <xavier.claessens@collabora.co.uk>
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <glib.h>
#include <glib/gi18n.h>
#include <gio/gio.h>
#include <telepathy-glib/telepathy-glib.h>

#include "tp-lowlevel.h"

static void
connection_get_alias_flags_cb (TpConnection *conn,
    guint flags,
    const GError *error,
    gpointer user_data,
    GObject *weak_object)
{
  GSimpleAsyncResult *simple = G_SIMPLE_ASYNC_RESULT (user_data);

  if (error != NULL)
    {
      g_simple_async_result_set_from_error (simple, error);
    }
  else
    {
      g_simple_async_result_set_op_res_gpointer (simple,
          GUINT_TO_POINTER (flags), NULL);
    }

  g_simple_async_result_complete (simple);
  g_object_unref (simple);
}

void
folks_tp_lowlevel_connection_get_alias_flags_async (
    TpConnection *conn,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  GSimpleAsyncResult *result;

  result = g_simple_async_result_new (G_OBJECT (conn), callback, user_data,
      folks_tp_lowlevel_connection_get_alias_flags_finish);

  tp_cli_connection_interface_aliasing_call_get_alias_flags (conn, -1,
      connection_get_alias_flags_cb, result, NULL, G_OBJECT (conn));
}

/**
 * folks_tp_lowlevel_connection_get_alias_flags_finish:
 * @result: a #GAsyncResult
 * @error: return location for a #GError, or %NULL
 *
 * Determine the alias-related capabilities of the #TpConnection.
 *
 * Returns: the #TpConnectionAliasFlags
 */
TpConnectionAliasFlags
folks_tp_lowlevel_connection_get_alias_flags_finish (
    GAsyncResult *result,
    GError **error)
{
  GSimpleAsyncResult *simple = G_SIMPLE_ASYNC_RESULT (result);
  TpConnection *conn;

  g_return_val_if_fail (G_IS_SIMPLE_ASYNC_RESULT (simple), FALSE);

  conn = TP_CONNECTION (g_async_result_get_source_object (result));
  g_return_val_if_fail (TP_IS_CONNECTION (conn), FALSE);

  if (g_simple_async_result_propagate_error (simple, error))
    return 0;

  g_return_val_if_fail (g_simple_async_result_is_valid (result,
      G_OBJECT (conn), folks_tp_lowlevel_connection_get_alias_flags_finish),
      0);

  return (TpConnectionAliasFlags) (g_simple_async_result_get_op_res_gpointer (
      G_SIMPLE_ASYNC_RESULT (result)));
}

static void
get_contacts_by_id_cb (TpConnection *conn,
    guint n_contacts,
    TpContact * const *contacts,
    const gchar * const *requested_ids,
    GHashTable *failed_id_errors,
    const GError *error,
    gpointer user_data,
    GObject *weak_object)
{
  GSimpleAsyncResult *simple = G_SIMPLE_ASYNC_RESULT (user_data);

  if (error != NULL)
    {
      g_simple_async_result_set_from_error (simple, error);
    }
  else
    {
      GList *contact_list = NULL;
      guint i;

      for (i = 0; i < n_contacts; i++)
        contact_list = g_list_prepend (contact_list,
            g_object_ref (contacts[i]));

      g_simple_async_result_set_op_res_gpointer (simple, contact_list, NULL);
    }

  g_simple_async_result_complete (simple);
  g_object_unref (simple);
}

/**
 * folks_tp_lowlevel_connection_get_contacts_by_id_async:
 * @conn: the connection to use
 * @contact_ids: (array length=contact_ids_length) (element-type utf8): the
 * contact IDs to get
 * @contact_ids_length: number of IDs in @contact_ids
 * @features: (array length=features_length): the features to use
 * @features_length: number of features in @features
 * @callback: function to call on completion
 * @user_data: user data to pass to @callback
 *
 * Get an array of #TpContact<!-- -->s for the given contact IDs.
 */
void
folks_tp_lowlevel_connection_get_contacts_by_id_async (
    TpConnection *conn,
    const char **contact_ids,
    guint contact_ids_length,
    guint *features,
    guint features_length,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  GSimpleAsyncResult *result;

  result = g_simple_async_result_new (G_OBJECT (conn), callback, user_data,
      folks_tp_lowlevel_connection_get_contacts_by_id_finish);

  tp_connection_get_contacts_by_id (conn,
      contact_ids_length,
      contact_ids,
      features_length,
      features,
      get_contacts_by_id_cb,
      result,
      NULL,
      G_OBJECT (conn));
}

/**
 * folks_tp_lowlevel_connection_get_contacts_by_id_finish:
 * @result: the async result
 * @error: a #GError, or %NULL
 *
 * Finish an operation started with
 * folks_tp_lowlevel_connection_get_contacts_by_id_async().
 *
 * Return value: (element-type TelepathyGLib.Contact) (transfer full): a list of
 * #TpContact<!-- -->s
 */
GList *
folks_tp_lowlevel_connection_get_contacts_by_id_finish (
    GAsyncResult *result,
    GError **error)
{
  GSimpleAsyncResult *simple = G_SIMPLE_ASYNC_RESULT (result);
  TpConnection *conn;

  g_return_val_if_fail (G_IS_SIMPLE_ASYNC_RESULT (simple), FALSE);

  conn = TP_CONNECTION (g_async_result_get_source_object (result));
  g_return_val_if_fail (TP_IS_CONNECTION (conn), FALSE);

  if (g_simple_async_result_propagate_error (simple, error))
    return NULL;

  g_return_val_if_fail (g_simple_async_result_is_valid (result, G_OBJECT (conn),
        folks_tp_lowlevel_connection_get_contacts_by_id_finish), NULL);

  return g_simple_async_result_get_op_res_gpointer (
      G_SIMPLE_ASYNC_RESULT (result));
}

static void
set_contact_alias_cb (TpConnection *conn,
    const GError *error,
    gpointer user_data,
    GObject *weak_object)
{
  if (error != NULL)
    {
      /* Translators: the parameter is an error message. */
      g_message (_("Failed to change contact's alias: %s"), error->message);
      return;
    }
}

void
folks_tp_lowlevel_connection_set_contact_alias (
    TpConnection *conn,
    guint handle,
    const gchar *alias)
{
  GHashTable *ht = g_hash_table_new_full (g_direct_hash, g_direct_equal, NULL,
      g_free);
  g_hash_table_insert (ht, GUINT_TO_POINTER (handle), g_strdup (alias));

  tp_cli_connection_interface_aliasing_call_set_aliases (conn, -1,
      ht, set_contact_alias_cb, NULL, NULL, NULL);

  g_hash_table_destroy (ht);
}
