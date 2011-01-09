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
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

#ifndef TP_TEST_BACKEND_H
#define TP_TEST_BACKEND_H

#include <glib.h>
#include <glib-object.h>

#include "conn.h"

G_BEGIN_DECLS

#define TP_TEST_TYPE_BACKEND (tp_test_backend_get_type ())
#define TP_TEST_BACKEND(o) (G_TYPE_CHECK_INSTANCE_CAST ((o), \
    TP_TEST_TYPE_BACKEND, TpTestBackend))
#define TP_TEST_BACKEND_CLASS(k) (G_TYPE_CHECK_CLASS_CAST((k), \
    TP_TEST_TYPE_BACKEND, TpTestBackendClass))
#define TP_TEST_IS_BACKEND(o) (G_TYPE_CHECK_INSTANCE_TYPE ((o), \
    TP_TEST_TYPE_BACKEND))
#define TP_TEST_IS_BACKEND_CLASS(k) (G_TYPE_CHECK_CLASS_TYPE ((k), \
    TP_TEST_TYPE_BACKEND))
#define TP_TEST_BACKEND_GET_CLASS(o) (G_TYPE_INSTANCE_GET_CLASS ((o), \
    TP_TEST_TYPE_BACKEND, TpTestBackendClass))

typedef struct _TpTestBackendPrivate TpTestBackendPrivate;

typedef struct
{
  /*< private >*/
  GObject parent;
  TpTestBackendPrivate *priv;
} TpTestBackend;

typedef struct
{
  /*< private > */
  GObjectClass parent;
} TpTestBackendClass;

GType tp_test_backend_get_type (void) G_GNUC_CONST;

TpTestBackend *tp_test_backend_new (void);

void tp_test_backend_set_up (TpTestBackend *self);
void tp_test_backend_tear_down (TpTestBackend *self);
TpTestContactListConnection *tp_test_backend_get_connection (
    TpTestBackend *self);

gpointer tp_test_backend_add_account (TpTestBackend *self,
    const gchar *protocol_name,
    const gchar *user_id,
    const gchar *connection_manager_name,
    const gchar *account_name);
void tp_test_backend_remove_account (TpTestBackend *self,
    gpointer handle);

G_END_DECLS

#endif /* !TP_TEST_BACKEND_H */
