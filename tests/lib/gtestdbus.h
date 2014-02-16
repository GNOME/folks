/* GIO testing utilities
 *
 * Copyright (C) 2008-2010 Red Hat, Inc.
 * Copyright (C) 2012 Collabora Ltd. <http://www.collabora.co.uk/>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General
 * Public License along with this library; if not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: David Zeuthen <davidz@redhat.com>
 *          Xavier Claessens <xavier.claessens@collabora.co.uk>
 */

#ifndef __FOLKS_TEST_DBUS_H__
#define __FOLKS_TEST_DBUS_H__

#include <gio/gio.h>

G_BEGIN_DECLS

/**
 * FolksTestDBusFlags:
 * @FOLKS_TEST_DBUS_NONE: No flags.
 * @FOLKS_TEST_DBUS_SESSION_BUS: Create a session bus (the default).
 * @FOLKS_TEST_DBUS_SYSTEM_BUS: Create a system bus instead of a session bus.
 *
 * Flags to define #FolksTestDBus behaviour.
 *
 * Since: 2.34
 */
typedef enum /*< flags >*/ {
  FOLKS_TEST_DBUS_NONE = 0,
  FOLKS_TEST_DBUS_SESSION_BUS = 0,  /* default; same as NONE */
  FOLKS_TEST_DBUS_SYSTEM_BUS = 1 << 0,
} FolksTestDBusFlags;

#define FOLKS_TYPE_TEST_DBUS_FLAGS (folks_test_dbus_flags_get_type ())
GType folks_test_dbus_flags_get_type (void) G_GNUC_CONST;

typedef struct _FolksTestDBus FolksTestDBus;


#define FOLKS_TYPE_TEST_DBUS \
    (folks_test_dbus_get_type ())
#define FOLKS_TEST_DBUS(obj) \
    (G_TYPE_CHECK_INSTANCE_CAST ((obj), FOLKS_TYPE_TEST_DBUS, \
        FolksTestDBus))
#define FOLKS_IS_TEST_DBUS(obj) \
    (G_TYPE_CHECK_INSTANCE_TYPE ((obj), FOLKS_TYPE_TEST_DBUS))

GLIB_AVAILABLE_IN_2_34
GType          folks_test_dbus_get_type        (void) G_GNUC_CONST;

GLIB_AVAILABLE_IN_2_34
FolksTestDBus *    folks_test_dbus_new             (FolksTestDBusFlags flags);

GLIB_AVAILABLE_IN_2_34
FolksTestDBusFlags folks_test_dbus_get_flags       (FolksTestDBus     *self);

GLIB_AVAILABLE_IN_2_34
const gchar *  folks_test_dbus_get_bus_address (FolksTestDBus     *self);

GLIB_AVAILABLE_IN_2_34
void           folks_test_dbus_add_service_dir (FolksTestDBus     *self,
                                            const gchar   *path);

GLIB_AVAILABLE_IN_2_34
void           folks_test_dbus_up              (FolksTestDBus     *self);

GLIB_AVAILABLE_IN_2_34
void           folks_test_dbus_stop            (FolksTestDBus     *self);

GLIB_AVAILABLE_IN_2_34
void           folks_test_dbus_down            (FolksTestDBus     *self);

GLIB_AVAILABLE_IN_2_34
void           folks_test_dbus_unset           (void);

G_END_DECLS

#endif /* __FOLKS_TEST_DBUS_H__ */
