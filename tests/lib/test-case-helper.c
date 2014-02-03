/* test-case-helper.c
 *
 * Copyright © 2013 Intel Corporation
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 *     Simon McVittie <simon.mcvittie@collabora.co.uk>
 */

#include "folks-test-internal.h"

#include <glib.h>
#include <glib-object.h>
#include <dbus/dbus.h>

typedef struct {
    gpointer self;
    FolksTestCaseTestMethod test;
} FolksTestCaseWeakMethod;

static void
folks_test_case_weak_method_setup (gpointer fixture G_GNUC_UNUSED,
    gconstpointer test_data)
{
  const FolksTestCaseWeakMethod *wm = test_data;

  g_return_if_fail (wm->self != NULL);
  g_return_if_fail (FOLKS_IS_TEST_CASE (wm->self));

  folks_test_case_set_up (wm->self);
}

static void
folks_test_case_weak_method_test (gpointer fixture G_GNUC_UNUSED,
    gconstpointer test_data)
{
  const FolksTestCaseWeakMethod *wm = test_data;

  g_return_if_fail (wm->self != NULL);
  g_return_if_fail (FOLKS_IS_TEST_CASE (wm->self));

  wm->test (wm->self);
}

static void
folks_test_case_weak_method_teardown (gpointer fixture G_GNUC_UNUSED,
    gconstpointer test_data)
{
  const FolksTestCaseWeakMethod *wm = test_data;

  g_return_if_fail (wm->self != NULL);
  g_return_if_fail (FOLKS_IS_TEST_CASE (wm->self));

  folks_test_case_tear_down (wm->self);
}

GTestCase *
folks_test_case_add_test_helper (FolksTestCase *self,
    const gchar *name,
    FolksTestCaseTestMethod test,
    void *test_target)
{
  FolksTestCaseWeakMethod *wm;

  g_return_val_if_fail (self == (FolksTestCase *) test_target, NULL);

  /* This will never be freed, so make sure not to hold references. */
  wm = g_new0 (FolksTestCaseWeakMethod, 1);
  wm->self = self;
  wm->test = test;
  g_object_add_weak_pointer (G_OBJECT (self), &wm->self);

  return g_test_create_case (name,
      0,
      wm,
      folks_test_case_weak_method_setup,
      folks_test_case_weak_method_test,
      folks_test_case_weak_method_teardown);
}

void
_folks_test_case_dbus_1_set_no_exit_on_disconnect (void)
{
  DBusConnection *conn = dbus_bus_get (DBUS_BUS_SESSION, NULL);

  if (conn != NULL)
    {
      dbus_connection_set_exit_on_disconnect (conn, FALSE);
      dbus_connection_unref (conn);
    }
}
