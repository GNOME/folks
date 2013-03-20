/* test-case.vala
 *
 * Copyright © 2011 Collabora Ltd.
 * Copyright © 2013 Intel Corporation
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Authors:
 *      Alban Crequy <alban.crequy@collabora.co.uk>
 *      Simon McVittie <simon.mcvittie@collabora.co.uk>
 */

/**
 * A test case for the libsocialweb backend. Folks is configured
 * to use that backend and no others, with no primary store.
 *
 * FIXME: for now, this relies on being run under with-session-bus.sh
 * with no activatable services.
 */
public class LibsocialwebTest.TestCase : Folks.TestCase
{
  /**
   * The libsocialweb test backend, or null outside the period from
   * set_up() to tear_down().
   *
   * If this is non-null, the subclass is expected to have called
   * its set_up() method at some point before tear_down() is reached.
   */
  public LibsocialwebTest.Backend? lsw_backend = null;

  public TestCase (string name)
    {
      /* This variable is set in the same place as the various variables we
       * care about for sandboxing purposes, like XDG_CONFIG_HOME and
       * DBUS_SESSION_BUS_ADDRESS. */
      if (Environment.get_variable ("FOLKS_TESTS_SANDBOXED_DBUS")
          != "no-services")
        error ("libsocialweb tests must be run in a private D-Bus session");

      base (name);

      Environment.set_variable ("FOLKS_BACKENDS_ALLOWED", "libsocialweb", true);
      Environment.set_variable ("FOLKS_PRIMARY_STORE", "", true);
    }

  public override void private_bus_up ()
    {
      /* Don't do anything. We're currently relying on
       * being wrapped in with-session-bus.sh. */
    }

  /**
   * Set up the libsocialweb test backend and wait for it to become ready.
   */
  public override void set_up ()
    {
      base.set_up ();

      this.lsw_backend = new LibsocialwebTest.Backend ();

      var lsw_backend = (!) this.lsw_backend;

      var main_loop = new GLib.MainLoop (null, false);

      this.lsw_backend.ready.connect (() =>
        {
          main_loop.quit ();
        });
      uint timer_id = Timeout.add_seconds (5, () =>
        {
          assert_not_reached ();
        });

      lsw_backend.set_up ();
      main_loop.run ();
      Source.remove (timer_id);
    }

  public override void tear_down ()
    {
      if (this.lsw_backend != null)
        {
          ((!) this.lsw_backend).tear_down ();
          this.lsw_backend = null;
        }

      base.tear_down ();
    }
}
