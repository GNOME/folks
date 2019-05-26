/* test-case-helper.c
 *
 * Copyright © 2013 Intel Corporation
 * Copyright © 2015 Collabora Ltd.
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

typedef struct {
    gpointer self;
    FolksTestCaseTestMethod test;
    gpointer test_data;
    GDestroyNotify test_data_free;
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

  wm->test (wm->test_data);
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

static void
test_case_destroyed_cb (gpointer data,
    GObject *test_case_location)
{
  FolksTestCaseWeakMethod *wm = data;

  if (wm->test_data != NULL && wm->test_data_free != NULL)
    wm->test_data_free (wm->test_data);
}

GTestCase *
folks_test_case_add_test_helper (FolksTestCase *self,
    const gchar *name,
    FolksTestCaseTestMethod test,
    void *test_target,
    GDestroyNotify test_target_destroy_notify)
{
  FolksTestCaseWeakMethod *wm;

  /* This will never be freed, so make sure not to hold references. */
  wm = g_new0 (FolksTestCaseWeakMethod, 1);
  wm->self = self;
  wm->test = test;
  wm->test_data = test_target;
  wm->test_data_free = test_target_destroy_notify;

  g_object_weak_ref (G_OBJECT (self), test_case_destroyed_cb, wm);

  return g_test_create_case (name,
      0,
      wm,
      folks_test_case_weak_method_setup,
      folks_test_case_weak_method_test,
      folks_test_case_weak_method_teardown);
}
