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

#include <dbus/dbus.h>

void
_tpf_test_test_case_dbus_1_set_no_exit_on_disconnect (void)
{
  DBusConnection *conn = dbus_bus_get (DBUS_BUS_SESSION, NULL);

  if (conn != NULL)
    {
      dbus_connection_set_exit_on_disconnect (conn, FALSE);
      dbus_connection_unref (conn);
    }
}
