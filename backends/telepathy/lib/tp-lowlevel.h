/*
 * Copyright (C) 2010 Collabora Ltd.
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
 */

#ifndef FOLKS_TP_LOWLEVEL_H
#define FOLKS_TP_LOWLEVEL_H

#include <glib.h>
#include <glib-object.h>
#include <gio/gio.h>
#include <telepathy-glib/channel.h>
#include <telepathy-glib/connection.h>
#include <telepathy-glib/contact.h>

G_BEGIN_DECLS

GQuark folks_tp_lowlevel_error_quark (void);
#define FOLKS_TP_LOWLEVEL_ERROR (folks_tp_lowlevel_error_quark ())

typedef enum {
  FOLKS_TP_LOWLEVEL_ERROR_INVALID_ARGUMENT,
} FolksTpLowlevelError;

/**
 * folks_tp_lowlevel_channel_group_change_membership:
 * @channel:
 * @handle:
 * @is_member:
 * @message: (allow-none):
 * @error:
 */
void
folks_tp_lowlevel_channel_group_change_membership (TpChannel *channel,
    guint handle,
    gboolean is_member,
    const gchar *message,
    GError **error);

/**
 * FolksTpLowlevelNewGroupChannelsCallback:
 * @channel: (allow-none) (transfer none): the new group #TpChannel
 * @result: the #GAsyncResult to finish the async call with
 * @user_data: extra data to pass to the callback
 *
 * The callback type for
 * folks_tp_lowlevel_connection_connect_to_new_group_channels().
 */
typedef void (*FolksTpLowlevelNewGroupChannelsCallback) (TpChannel *channel,
    GAsyncResult *result,
    gpointer user_data);

void
folks_tp_lowlevel_connection_connect_to_new_group_channels (
    TpConnection *conn,
    FolksTpLowlevelNewGroupChannelsCallback callback,
    gpointer user_data);

void
folks_tp_lowlevel_connection_create_group_async (
    TpConnection *conn,
    const char *name);

void
folks_tp_lowlevel_connection_set_contact_alias (
    TpConnection *conn,
    guint handle,
    const gchar *alias);

void
folks_tp_lowlevel_connection_open_contact_list_channel_async (
    TpConnection *conn,
    const char *name,
    GAsyncReadyCallback callback,
    gpointer user_data);

TpChannel *
folks_tp_lowlevel_connection_open_contact_list_channel_finish (
    GAsyncResult *result,
    GError **error);

void
folks_tp_lowlevel_connection_get_alias_flags_async (
    TpConnection *conn,
    GAsyncReadyCallback callback,
    gpointer user_data);

TpConnectionAliasFlags
folks_tp_lowlevel_connection_get_alias_flags_finish (
    GAsyncResult *result,
    GError **error);

void
folks_tp_lowlevel_connection_get_contacts_by_handle_async (
    TpConnection *conn,
    const guint *contact_handles,
    guint contact_handles_length,
    const guint *features,
    guint features_length,
    GAsyncReadyCallback callback,
    gpointer user_data);

GList *
folks_tp_lowlevel_connection_get_contacts_by_handle_finish (
    GAsyncResult *result,
    GError **error);

void
folks_tp_lowlevel_connection_get_contacts_by_id_async (
    TpConnection *conn,
    const char **contact_ids,
    guint contact_ids_length,
    guint *features,
    guint features_length,
    GAsyncReadyCallback callback,
    gpointer user_data);

GList *
folks_tp_lowlevel_connection_get_contacts_by_id_finish (
    GAsyncResult *result,
    GError **error);

void
folks_tp_lowlevel_connection_get_requestable_channel_classes_async (
    TpConnection *conn,
    GAsyncReadyCallback callback,
    gpointer user_data);

GPtrArray *
folks_tp_lowlevel_connection_get_requestable_channel_classes_finish (
    GAsyncResult *result,
    GError **error);

G_END_DECLS

#endif /* FOLKS_TP_LOWLEVEL_H */
