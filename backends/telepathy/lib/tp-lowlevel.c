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
#include <telepathy-glib/channel.h>
#include <telepathy-glib/connection.h>
#include <telepathy-glib/dbus.h>
#include <telepathy-glib/interfaces.h>
#include <telepathy-glib/util.h>

#include "tp-lowlevel.h"

GQuark
folks_tp_lowlevel_error_quark (void)
{
  static GQuark quark = 0;

  if (quark == 0)
    quark = g_quark_from_static_string ("folks-tp_lowlevel");

  return quark;
}

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
      g_simple_async_result_set_from_error (simple, error);
    }
  else
    {
      TpChannel *channel;

      /* FIXME: pass in an error here and react to it */
      channel = tp_channel_new_from_properties (conn, path, properties, NULL);
      g_simple_async_result_set_op_res_gpointer (simple, g_object_ref (channel),
          (GDestroyNotify) g_object_unref);

      g_object_unref (channel);
    }

  g_simple_async_result_complete (simple);
  g_object_unref (simple);
}

void
folks_tp_lowlevel_connection_open_contact_list_channel_async (
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
      folks_tp_lowlevel_connection_open_contact_list_channel_finish);
  tp_cli_connection_interface_requests_call_ensure_channel (conn, -1, request,
      connection_ensure_channel_cb, result, NULL, G_OBJECT (conn));

  g_hash_table_unref (request);
}

/**
 * folks_tp_lowlevel_connection_open_contact_list_channel_finish:
 * @result: a #GAsyncResult
 * @error: return location for a #GError, or %NULL
 *
 * Finish an asynchronous operation to open a contact list channel, started with
 * folks_tp_lowlevel_connection_open_contact_list_channel_async().
 *
 * Returns: (transfer none): the ensured-valid #TpChannel
 */
TpChannel *
folks_tp_lowlevel_connection_open_contact_list_channel_finish (
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
        folks_tp_lowlevel_connection_open_contact_list_channel_finish), NULL);

  return g_simple_async_result_get_op_res_gpointer (
      G_SIMPLE_ASYNC_RESULT (result));
}

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
get_contacts_by_handle_cb (TpConnection *conn,
    guint n_contacts,
    TpContact * const *contacts,
    guint n_failed,
    const guint *failed_handles,
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
 * folks_tp_lowlevel_connection_get_contacts_by_handle_async:
 * @conn: the connection to use
 * @contact_handles: (array length=contact_handles_length): the contact handles
 * to get
 * @contact_handles_length: number of handles in @contact_handles
 * @features: (array length=features_length): the features to use
 * @features_length: number of features in @features
 * @callback: function to call on completion
 * @user_data: user data to pass to @callback
 *
 * Get an array of #TpContact<!-- -->s for the given contact handles.
 */
void
folks_tp_lowlevel_connection_get_contacts_by_handle_async (
    TpConnection *conn,
    const guint *contact_handles,
    guint contact_handles_length,
    const guint *features,
    guint features_length,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  GSimpleAsyncResult *result;

  result = g_simple_async_result_new (G_OBJECT (conn), callback, user_data,
      folks_tp_lowlevel_connection_get_contacts_by_handle_finish);

  tp_connection_get_contacts_by_handle (conn,
      contact_handles_length,
      contact_handles,
      features_length,
      features,
      get_contacts_by_handle_cb,
      result,
      NULL,
      G_OBJECT (conn));
}

/**
 * folks_tp_lowlevel_connection_get_contacts_by_handle_finish:
 * @result: the async result
 * @error: a #GError, or %NULL
 *
 * Finish an operation started with
 * folks_tp_lowlevel_connection_get_contacts_by_handle_async().
 *
 * Return value: (element-type TelepathyGLib.Contact) (transfer full): a list of
 * #TpContact<!-- -->s
 */
GList *
folks_tp_lowlevel_connection_get_contacts_by_handle_finish (
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
        folks_tp_lowlevel_connection_get_contacts_by_handle_finish), NULL);

  return g_simple_async_result_get_op_res_gpointer (
      G_SIMPLE_ASYNC_RESULT (result));
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
connection_get_requestable_channel_classes_cb (TpProxy *conn,
    const GValue *value,
    const GError *error,
    gpointer user_data,
    GObject *weak_object)
{
  GSimpleAsyncResult *simple = G_SIMPLE_ASYNC_RESULT (user_data);
  GPtrArray *props;

  if (error != NULL)
    {
      g_simple_async_result_set_from_error (simple, error);
    }
  else
    {
      props = (GPtrArray*) g_value_get_boxed (value);
      g_simple_async_result_set_op_res_gpointer (simple,
          g_ptr_array_ref (props), (GDestroyNotify) g_ptr_array_unref);
    }

  g_simple_async_result_complete (simple);
  g_object_unref (simple);
}

void
folks_tp_lowlevel_connection_get_requestable_channel_classes_async (
    TpConnection *conn,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  GSimpleAsyncResult *result;

  result = g_simple_async_result_new (G_OBJECT (conn), callback, user_data,
      folks_tp_lowlevel_connection_get_requestable_channel_classes_finish);

  tp_cli_dbus_properties_call_get (conn, -1,
      TP_IFACE_CONNECTION_INTERFACE_REQUESTS, "RequestableChannelClasses",
      connection_get_requestable_channel_classes_cb, result, NULL,
      G_OBJECT (conn));
}

/**
 * folks_tp_lowlevel_connection_get_requestable_channel_classes_finish:
 * @result: a #GAsyncResult
 * @error: return location for a #GError, or %NULL
 *
 * Retrieve the #TpConnection's RequestableChannelClasses D-Bus property.
 *
 * Returns: (transfer full): the boxed property details. Unref with
 * g_ptr_array_unref().
 */
GPtrArray *
folks_tp_lowlevel_connection_get_requestable_channel_classes_finish (
    GAsyncResult *result,
    GError **error)
{
  GSimpleAsyncResult *simple = G_SIMPLE_ASYNC_RESULT (result);
  GPtrArray *props;
  TpConnection *conn;

  g_return_val_if_fail (G_IS_SIMPLE_ASYNC_RESULT (simple), NULL);

  conn = TP_CONNECTION (g_async_result_get_source_object (result));
  g_return_val_if_fail (TP_IS_CONNECTION (conn), NULL);

  if (g_simple_async_result_propagate_error (simple, error))
    return NULL;

  g_return_val_if_fail (g_simple_async_result_is_valid (result,
      G_OBJECT (conn),
      folks_tp_lowlevel_connection_get_requestable_channel_classes_finish),
      NULL);

  props = (GPtrArray*) g_simple_async_result_get_op_res_gpointer (
      G_SIMPLE_ASYNC_RESULT (result));
  return g_ptr_array_ref (props);
}

static void
group_request_channel_cb (
    TpConnection *conn,
    const gchar *object_path,
    const GError *error,
    gpointer user_data,
    GObject *list)
{
  /* The new channel will be handled by the NewChannels handler. Here we only
   * handle the error if RequestChannel failed */
  if (error)
    {
      /* Translators: the parameter is an error message. */
      g_message (_("Error requesting a group channel: %s"), error->message);
      return;
    }
}

static void
group_request_handles_cb (
    TpConnection *conn,
    const GArray *handles,
    const GError *error,
    gpointer user_data,
    GObject *weak_object)
{
  guint channel_handle;

  if (error)
    {
      /* Translators: the parameter is an error message. */
      g_message (_("Error requesting group handles: %s"), error->message);
      return;
    }

  channel_handle = g_array_index (handles, guint, 0);
  tp_cli_connection_call_request_channel (conn, -1,
    TP_IFACE_CHANNEL_TYPE_CONTACT_LIST,
    TP_HANDLE_TYPE_GROUP,
    channel_handle,
    TRUE,
    group_request_channel_cb,
    NULL, NULL,
    weak_object);
}

void
folks_tp_lowlevel_connection_create_group_async (
    TpConnection *conn,
    const char *group)
{
  const gchar *names[] = { group, NULL };

  tp_cli_connection_call_request_handles (conn, -1,
      TP_HANDLE_TYPE_GROUP, names,
      group_request_handles_cb,
      NULL, NULL,
      G_OBJECT (conn));
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

static void
iterate_on_channels (TpConnection *conn,
    const GPtrArray *channels,
    gpointer user_data,
    GObject *weak_object)
{
  FolksTpLowlevelNewGroupChannelsCallback callback = user_data;
  GObject *cb_obj = weak_object;
  guint i;

  for (i = 0; i < channels->len ; i++) {
    GValueArray *arr = g_ptr_array_index (channels, i);
    const gchar *path;
    GHashTable *properties;
    TpHandleType handle_type;
    TpChannel *channel;
    GError *error = NULL;

    path = g_value_get_boxed (g_value_array_get_nth (arr, 0));
    properties = g_value_get_boxed (g_value_array_get_nth (arr, 1));

    if (tp_strdiff (tp_asv_get_string (properties,
        TP_IFACE_CHANNEL ".ChannelType"),
        TP_IFACE_CHANNEL_TYPE_CONTACT_LIST))
      continue;

    if (tp_asv_get_string (properties, TP_IFACE_CHANNEL ".TargetID") == NULL)
      continue;

    handle_type = tp_asv_get_uint32 (properties,
      TP_IFACE_CHANNEL ".TargetHandleType", NULL);

    if (handle_type != TP_HANDLE_TYPE_GROUP)
      continue;

    channel = tp_channel_new_from_properties (conn, path, properties, &error);
    if (channel == NULL) {
      /* Translators: the parameter is an error message. */
      g_message (_("Failed to create group channel: %s"), error->message);
      g_error_free (error);
      return;
    }

    if (callback)
      callback (channel, NULL, cb_obj);

    g_object_unref (channel);
  }
}

static void
new_group_channels_cb (TpConnection *conn,
    const GPtrArray *channels,
    gpointer user_data,
    GObject *weak_object)
{
  iterate_on_channels (conn, channels, user_data, weak_object);
}

static void
got_channels_cb (TpProxy *conn,
    const GValue *out,
    const GError *error,
    gpointer user_data,
    GObject *weak_object)
{
  const GPtrArray *channels;

  if (error != NULL) {
    /* Translators: the parameter is an error message. */
    g_message (_("Get Channels property failed: %s"), error->message);
    return;
  }

  channels = g_value_get_boxed (out);
  iterate_on_channels (TP_CONNECTION (conn), channels, user_data, weak_object);
}

/**
 * folks_tp_lowlevel_connection_connect_to_new_group_channels:
 * @conn: the connection to use
 * @callback: (scope call): function to call on completion
 * @user_data: (closure): user data to pass to @callback
 *
 * Connect to the NewChannels signal.
 */
void
folks_tp_lowlevel_connection_connect_to_new_group_channels (
    TpConnection *conn,
    FolksTpLowlevelNewGroupChannelsCallback callback,
    gpointer user_data)
{
  /* Look for existing group channels */
  tp_cli_dbus_properties_call_get (conn, -1,
      TP_IFACE_CONNECTION_INTERFACE_REQUESTS, "Channels", got_channels_cb,
      G_CALLBACK (callback), NULL, G_OBJECT (user_data));

  tp_cli_connection_interface_requests_connect_to_new_channels (
      conn, new_group_channels_cb, G_CALLBACK (callback), NULL, user_data,
      NULL);
}

static void
group_add_members_cb (TpChannel *proxy,
    const GError *error,
    gpointer user_data,
    GObject *weak_object)
{
  if (error != NULL)
    {
      /* Translators: the first parameter is a group channel identifier and the
       * second is an error message. */
      g_message (_("Failed to add contact to group '%s': %s"),
          tp_channel_get_identifier (TP_CHANNEL (proxy)), error->message);
      return;
    }
}

static void
group_remove_members_cb (TpChannel *proxy,
    const GError *error,
    gpointer user_data,
    GObject *weak_object)
{
  if (error != NULL)
    {
      /* Translators: the first parameter is a group channel identifier and the
       * second is an error message. */
      g_message (_("Failed to remove contact from group '%s': %s"),
          tp_channel_get_identifier (TP_CHANNEL (proxy)), error->message);
      return;
    }
}

/* XXX: there doesn't seem to be a way to make this throw a Folks.TpLowlevelError
 * (vs. the generic GLib.Error) */
void
folks_tp_lowlevel_channel_group_change_membership (TpChannel *channel,
    guint handle,
    gboolean is_member,
    const gchar *message,
    GError **error)
{
  GArray *handles;

  if (!TP_IS_CHANNEL (channel))
    {
      g_set_error (error, FOLKS_TP_LOWLEVEL_ERROR,
          FOLKS_TP_LOWLEVEL_ERROR_INVALID_ARGUMENT,
          /* Translators: the first parameter is a pointer address and the
           * second is a contact handle (numeric identifier). */
          _("Invalid group channel %p to add handle %d to."), channel, handle);
    }

  handles = g_array_new (FALSE, TRUE, sizeof (guint));
  g_array_append_val (handles, handle);

  if (is_member)
    {
      tp_cli_channel_interface_group_call_add_members (channel, -1, handles,
          message, group_add_members_cb, NULL, NULL, NULL);
    }
  else
    {
      tp_cli_channel_interface_group_call_remove_members (channel, -1, handles,
          message, group_remove_members_cb, NULL, NULL, NULL);
    }

  g_array_free (handles, TRUE);
}
