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
      base (name);

      Environment.set_variable ("FOLKS_BACKENDS_ALLOWED", "libsocialweb", true);
      Environment.set_variable ("FOLKS_PRIMARY_STORE", "", true);
    }

  /**
   * This test does use libdbus, via libsocialweb.
   */
  public override bool uses_dbus_1
    {
      get
        {
          return true;
        }
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

      lsw_backend.set_up ();
      Folks.TestUtils.loop_run_with_timeout (main_loop, 5);
    }

  public override void tear_down ()
    {
      if (this.lsw_backend != null)
        {
          ((!) this.lsw_backend).tear_down ();
          this.lsw_backend = null;
        }

      /* Ensure that all pending operations are complete.
       *
       * FIXME: This should be eliminated and unprepare() should guarantee there
       * are no more pending Backend/PersonaStore events.
       *
       * https://bugzilla.gnome.org/show_bug.cgi?id=727700 */
      var context = MainContext.default ();
      while (context.iteration (false));

      base.tear_down ();
    }
}
