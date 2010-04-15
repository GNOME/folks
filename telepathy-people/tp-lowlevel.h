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

#ifndef TP_LOWLEVEL_H
#define TP_LOWLEVEL_H

#include <glib.h>
#include <glib-object.h>
#include <gio/gio.h>
#include <telepathy-glib/channel.h>
#include <telepathy-glib/connection.h>

G_BEGIN_DECLS

typedef struct _TpLowlevel TpLowlevel;
typedef struct _TpLowlevelClass TpLowlevelClass;

struct _TpLowlevel {
  /*<private>*/
  GObject parent;
};

struct _TpLowlevelClass {
  /*<private>*/
  GObjectClass parent_class;
};

GType tp_lowlevel_get_type (void);

#define TP_TYPE_LOWLEVEL (tp_lowlevel_get_type ())
#define TP_LOWLEVEL(object) (G_TYPE_CHECK_INSTANCE_CAST ((object), TP_TYPE_LOWLEVEL, TpLowlevel))
#define TP_LOWLEVEL_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), TP_TYPE_LOWLEVEL, TpLowlevelClass))
#define TP_IS_LOWLEVEL(object) (G_TYPE_CHECK_INSTANCE_TYPE ((object), TP_TYPE_LOWLEVEL))
#define TP_IS_LOWLEVEL_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), TP_TYPE_LOWLEVEL))
#define TP_LOWLEVEL_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TYPE_LOWLEVEL, TpLowlevelClass))

TpLowlevel *
tp_lowlevel_new (void) G_GNUC_WARN_UNUSED_RESULT;

void
tp_lowlevel_connection_open_contact_list_channel_async (TpLowlevel *lowlevel,
    TpConnection *conn,
    const char *name,
    GAsyncReadyCallback callback,
    gpointer user_data);

const TpChannel *
tp_lowlevel_connection_open_contact_list_channel_finish (TpLowlevel *lowlevel,
    TpConnection *conn,
    GAsyncResult *result,
    GError **error);

G_END_DECLS

#endif /* TP_LOWLEVEL_H */
