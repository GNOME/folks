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

typedef struct _FolksTpLowlevel FolksTpLowlevel;
typedef struct _FolksTpLowlevelClass FolksTpLowlevelClass;

struct _FolksTpLowlevel {
  /*<private>*/
  GObject parent;
};

struct _FolksTpLowlevelClass {
  /*<private>*/
  GObjectClass parent_class;
};

GType folks_tp_lowlevel_get_type (void);

#define FOLKS_TYPE_TP_LOWLEVEL (folks_tp_lowlevel_get_type ())
#define FOLKS_TP_LOWLEVEL(object) (G_TYPE_CHECK_INSTANCE_CAST ((object), FOLKS_TYPE_TP_LOWLEVEL, FolksTpLowlevel))
#define FOLKS_TP_LOWLEVEL_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), FOLKS_TYPE_TP_LOWLEVEL, FolksTpLowlevelClass))
#define FOLKS_IS_TP_LOWLEVEL(object) (G_TYPE_CHECK_INSTANCE_TYPE ((object), FOLKS_TYPE_TP_LOWLEVEL))
#define FOLKS_IS_TP_LOWLEVEL_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), FOLKS_TYPE_TP_LOWLEVEL))
#define FOLKS_TP_LOWLEVEL_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), FOLKS_TYPE_TP_LOWLEVEL, FolksTpLowlevelClass))

GQuark folks_error_quark (void);
GQuark folks_tp_lowlevel_error_quark (void);

#define FOLKS_TP_LOWLEVEL_ERROR (folks_tp_lowlevel_error_quark ())
typedef enum {
  FOLKS_TP_LOWLEVEL_ERROR_INVALID_ARGUMENT,
} FolksTpLowlevelError;

FolksTpLowlevel *
folks_tp_lowlevel_new (void) G_GNUC_WARN_UNUSED_RESULT;

void
folks_tp_lowlevel_channel_group_change_membership (TpChannel *channel,
    TpHandle handle,
    gboolean is_member,
    GError **error);

void
folks_tp_lowlevel_connection_connect_to_new_group_channels (
    FolksTpLowlevel *lowlevel,
    TpConnection *conn,
    GFunc callback,
    gpointer user_data);

void
folks_tp_lowlevel_connection_create_group_async (
    FolksTpLowlevel *lowlevel,
    TpConnection *conn,
    const char *name);

void
folks_tp_lowlevel_connection_open_contact_list_channel_async (
    FolksTpLowlevel *lowlevel,
    TpConnection *conn,
    const char *name,
    GAsyncReadyCallback callback,
    gpointer user_data);

TpChannel *
folks_tp_lowlevel_connection_open_contact_list_channel_finish (
    FolksTpLowlevel *lowlevel,
    GAsyncResult *result,
    GError **error);

void
folks_tp_lowlevel_connection_get_contacts_by_id_async (
    FolksTpLowlevel *tp_lowlevel,
    TpConnection *conn,
    const char **contact_ids,
    guint contact_ids_length,
    TpContactFeature *features,
    guint features_length,
    GAsyncReadyCallback callback,
    gpointer user_data);

GList *
folks_tp_lowlevel_connection_get_contacts_by_id_finish (
    FolksTpLowlevel *tp_lowlevel,
    GAsyncResult *result,
    GError **error);

G_END_DECLS

#endif /* FOLKS_TP_LOWLEVEL_H */
