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
set_contact_alias_cb (TpConnection *conn,
    const GError *error,
    gpointer user_data,
    GObject *weak_object)
{
  GTask *task = G_TASK (user_data);

  if (error != NULL)
    {
      g_task_return_error (task, g_error_copy (error));
    }
  else
    {
      g_task_return_boolean (task, TRUE);
    }
}

/**
 * folks_tp_lowlevel_connection_set_contact_alias_async:
 * @conn: the connection to use
 * @handle: handle of the contact whose alias is to be changed
 * @alias: new human-readable alias for the contact
 * @callback: function to call on completion
 * @user_data: user data to pass to @callback
 *
 * Change the alias of the contact identified by @handle to @alias.
 */
void
folks_tp_lowlevel_connection_set_contact_alias_async (
    TpConnection *conn,
    guint handle,
    const gchar *alias,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  g_autoptr(GTask) task = NULL;
  g_autoptr(GHashTable) ht = NULL;

  ht = g_hash_table_new_full (g_direct_hash, g_direct_equal, NULL, g_free);
  g_hash_table_insert (ht, GUINT_TO_POINTER (handle), g_strdup (alias));

  task = g_task_new (conn, NULL, callback, user_data);
  g_task_set_source_tag (task,
      folks_tp_lowlevel_connection_set_contact_alias_async);

  tp_cli_connection_interface_aliasing_call_set_aliases (conn, -1,
      ht, set_contact_alias_cb, g_steal_pointer (&task), g_object_unref,
      G_OBJECT (conn));
}

/**
 * folks_tp_lowlevel_connection_set_contact_alias_finish:
 * @result: a #GAsyncResult
 * @error: return location for a #GError, or %NULL
 *
 * Finish an asynchronous call to
 * folks_tp_lowlevel_connection-set_contact_alias_async().
 */
void
folks_tp_lowlevel_connection_set_contact_alias_finish (
    GAsyncResult *result,
    GError **error)
{
  TpConnection *conn;

  g_return_if_fail (G_IS_TASK (result));

  conn = TP_CONNECTION (g_task_get_source_object (G_TASK (result)));
  g_return_if_fail (TP_IS_CONNECTION (conn));

  g_return_if_fail (g_task_is_valid (result, conn));
  g_return_if_fail (g_task_get_source_tag (G_TASK (result)) ==
      folks_tp_lowlevel_connection_set_contact_alias_async);

  /* Note: We throw away the boolean return value here */
  g_task_propagate_boolean (G_TASK (result), error);
}
