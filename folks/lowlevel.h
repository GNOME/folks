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

#ifndef FOLKS_LOWLEVEL_H
#define FOLKS_LOWLEVEL_H

#include <glib.h>
#include <glib-object.h>
#include <gio/gio.h>
#include <telepathy-glib/channel.h>
#include <telepathy-glib/connection.h>

G_BEGIN_DECLS

typedef struct _FolksLowlevel FolksLowlevel;
typedef struct _FolksLowlevelClass FolksLowlevelClass;

struct _FolksLowlevel {
  /*<private>*/
  GObject parent;
};

struct _FolksLowlevelClass {
  /*<private>*/
  GObjectClass parent_class;
};

GType folks_lowlevel_get_type (void);

#define FOLKS_TYPE_LOWLEVEL (folks_lowlevel_get_type ())
#define FOLKS_LOWLEVEL(object) (G_TYPE_CHECK_INSTANCE_CAST ((object), FOLKS_TYPE_LOWLEVEL, FolksLowlevel))
#define FOLKS_LOWLEVEL_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), FOLKS_TYPE_LOWLEVEL, FolksLowlevelClass))
#define FOLKS_IS_LOWLEVEL(object) (G_TYPE_CHECK_INSTANCE_TYPE ((object), FOLKS_TYPE_LOWLEVEL))
#define FOLKS_IS_LOWLEVEL_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), FOLKS_TYPE_LOWLEVEL))
#define FOLKS_LOWLEVEL_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), FOLKS_TYPE_LOWLEVEL, FolksLowlevelClass))

FolksLowlevel *
folks_lowlevel_new (void) G_GNUC_WARN_UNUSED_RESULT;

void
folks_lowlevel_connection_connect_to_new_group_channels (
    FolksLowlevel *lowlevel,
    TpConnection *conn,
    GFunc callback,
    gpointer user_data);

void
folks_lowlevel_connection_open_contact_list_channel_async (
    FolksLowlevel *lowlevel,
    TpConnection *conn,
    const char *name,
    GAsyncReadyCallback callback,
    gpointer user_data);

TpChannel *
folks_lowlevel_connection_open_contact_list_channel_finish (
    FolksLowlevel *lowlevel,
    GAsyncResult *result,
    GError **error);

G_END_DECLS

#endif /* FOLKS_LOWLEVEL_H */
