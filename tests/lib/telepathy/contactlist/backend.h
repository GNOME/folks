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

#ifndef TP_TESTS_BACKEND_H
#define TP_TESTS_BACKEND_H

#include <glib.h>
#include <glib-object.h>

#include "contacts-conn.h"

G_BEGIN_DECLS

#define TP_TESTS_TYPE_BACKEND (tp_tests_backend_get_type ())
#define TP_TESTS_BACKEND(o) (G_TYPE_CHECK_INSTANCE_CAST ((o), \
    TP_TESTS_TYPE_BACKEND, TpTestsBackend))
#define TP_TESTS_BACKEND_CLASS(k) (G_TYPE_CHECK_CLASS_CAST((k), \
    TP_TESTS_TYPE_BACKEND, TpTestsBackendClass))
#define TP_TESTS_IS_BACKEND(o) (G_TYPE_CHECK_INSTANCE_TYPE ((o), \
    TP_TESTS_TYPE_BACKEND))
#define TP_TESTS_IS_BACKEND_CLASS(k) (G_TYPE_CHECK_CLASS_TYPE ((k), \
    TP_TESTS_TYPE_BACKEND))
#define TP_TESTS_BACKEND_GET_CLASS(o) (G_TYPE_INSTANCE_GET_CLASS ((o), \
    TP_TESTS_TYPE_BACKEND, TpTestsBackendClass))

typedef struct _TpTestsBackendPrivate TpTestsBackendPrivate;

typedef struct
{
  /*< private >*/
  GObject parent;
  TpTestsBackendPrivate *priv;
} TpTestsBackend;

typedef struct
{
  /*< private > */
  GObjectClass parent;
} TpTestsBackendClass;

GType tp_tests_backend_get_type (void) G_GNUC_CONST;

TpTestsBackend *tp_tests_backend_new (void);

void tp_tests_backend_set_up (TpTestsBackend *self);
void tp_tests_backend_tear_down (TpTestsBackend *self);

TpTestsContactsConnection *tp_tests_backend_get_connection_for_handle (
    TpTestsBackend *self,
    gpointer handle);

gpointer tp_tests_backend_add_account (TpTestsBackend *self,
    const gchar *protocol,
    const gchar *user_id,
    const gchar *cm_name,
    const gchar *account);
void tp_tests_backend_remove_account (TpTestsBackend *self,
    gpointer handle);

G_END_DECLS

#endif /* !TP_TESTS_BACKEND_H */
