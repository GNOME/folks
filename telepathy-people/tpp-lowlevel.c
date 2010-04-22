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

#include <glib.h>
#include <gio/gio.h>
#include <telepathy-glib/channel.h>
#include <telepathy-glib/connection.h>
#include <telepathy-glib/dbus.h>
#include <telepathy-glib/interfaces.h>

#include "tpp-lowlevel.h"

G_DEFINE_TYPE (TppLowlevel, tpp_lowlevel, G_TYPE_OBJECT);

static void
connection_ensure_channel_cb (TpConnection *conn,
    gboolean yours,
    const gchar *path,
    GHashTable *properties,
    const GError *error,
    gpointer user_data,
    GObject *weak_object)
{
  GSimpleAsyncResult *simple = G_SIMPLE_ASYNC_RESULT (user_data);

  if (error != NULL)
    {
      g_warning ("failed to ensure channel: %s\n", error->message);
      g_simple_async_result_set_from_error (simple, error);
    }
  else
    {
      TpChannel *channel;

      /* FIXME: pass in an error here and react to it */
      channel = tp_channel_new_from_properties (conn, path, properties, NULL);
      g_simple_async_result_set_op_res_gpointer (simple, g_object_ref (channel),
          g_object_unref);

      g_object_unref (channel);
    }

  g_simple_async_result_complete (simple);
  g_object_unref (simple);
}

void
tpp_lowlevel_connection_open_contact_list_channel_async (TppLowlevel *lowlevel,
    TpConnection *conn,
    const char *name,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  GSimpleAsyncResult *result;
  GHashTable *request;

  request = tp_asv_new (TP_IFACE_CHANNEL ".ChannelType", G_TYPE_STRING,
      TP_IFACE_CHANNEL_TYPE_CONTACT_LIST, TP_IFACE_CHANNEL ".TargetHandleType",
      G_TYPE_UINT, TP_HANDLE_TYPE_LIST, NULL);

  tp_asv_set_static_string (request, TP_IFACE_CHANNEL ".TargetID", name);
  result = g_simple_async_result_new (G_OBJECT (conn), callback, user_data,
      tpp_lowlevel_connection_open_contact_list_channel_finish);
  tp_cli_connection_interface_requests_call_ensure_channel (conn, -1, request,
      connection_ensure_channel_cb, result, NULL, G_OBJECT (conn));
}

/* XXX: ideally, we'd either make this static or hide it in the .metadata file,
 * but neither seems to be supported (without breaking the binding to the async
 * function) */
TpChannel *
tpp_lowlevel_connection_open_contact_list_channel_finish (TppLowlevel *lowlevel,
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
        tpp_lowlevel_connection_open_contact_list_channel_finish), NULL);

  return g_simple_async_result_get_op_res_gpointer (
      G_SIMPLE_ASYNC_RESULT (result));
}

static void
tpp_lowlevel_class_init (TppLowlevelClass *klass)
{
}

static void
tpp_lowlevel_init (TppLowlevel *self)
{
}

TppLowlevel *
tpp_lowlevel_new ()
{
  return TPP_LOWLEVEL (g_object_new (TPP_TYPE_LOWLEVEL, NULL));
}
