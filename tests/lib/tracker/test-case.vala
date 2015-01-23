/* test-case.vala
 *
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
 * Author:
 *      Simon McVittie <simon.mcvittie@collabora.co.uk>
 */

/**
 * A test case for the Tracker backend.
 *
 * Folks is configured to use the Tracker backend as primary store,
 * and no other backends.
 *
 * This uses tracker-control to start and stop Tracker services on a private
 * D-Bus bus.
 */
public class TrackerTest.TestCase : Folks.TestCase
{
  /**
   * The Tracker backend.
   *
   * The subclass is expected to have called its set_up() method at
   * some point before tear_down() is reached.
   */
  public TrackerTest.Backend? tracker_backend = null;

  /**
   * Set environment variables and create the tracker backend.
   *
   * FIXME: maybe it shouldn't be created until set_up()? (Tests
   * will need to be checked to make sure that's OK.)
   */
  public TestCase (string name)
    {
      base (name);

      Environment.set_variable ("FOLKS_BACKENDS_ALLOWED", "tracker", true);
      Environment.set_variable ("FOLKS_PRIMARY_STORE", "tracker", true);
    }

  private string _get_tracker_libexecdir ()
    {
      /* Try the environment variable first, since when running installed
       * tests we can’t depend on pkg-config being available. */
      var env = Environment.get_variable ("FOLKS_TEST_TRACKER_LIBEXECDIR");

      if (env != null && env != "")
        {
          return env;
        }

      /* Find out the libexec directory to use. */
      int exit_status = -1;
      string capture_stdout = null;

      try
        {
          Process.spawn_sync (null /* cwd */,
              { "pkg-config", "--variable=prefix",
              "tracker-miner-%s".printf(Folks.BuildConf.TRACKER_SPARQL_MAJOR)},
              null /* envp */,
              SpawnFlags.SEARCH_PATH /* flags */,
              null /* child setup */,
              out capture_stdout,
              null /* do not capture stderr */,
              out exit_status);

          Process.check_exit_status (exit_status);
        }
      catch (GLib.Error e1)
        {
          error ("Error getting libexecdir from pkg-config: %s", e1.message);
        }

      /* FIXME: There really should be a libexec variable in the pkg-config
       * file. */
      return capture_stdout.strip () + "/libexec";
    }

  public override void private_bus_up ()
    {
      base.private_bus_up ();

      /* Find out the libexec directory to use. */
      var libexec = this._get_tracker_libexecdir ();

      /* Create service files for the Tracker binaries. */
      var service_file_name =
          Path.build_filename (this.transient_dir, "dbus-1", "services",
              "org.freedesktop.Tracker1.service");
      var service_file = ("[D-BUS Service]\n" +
          "Name=org.freedesktop.Tracker1\n" +
          "Exec=%s/tracker-store\n").printf (libexec);

      try
        {
          FileUtils.set_contents (service_file_name, service_file);
        }
      catch (FileError e2)
        {
          error ("Error creating D-Bus service file ‘%s’: %s",
              service_file_name, e2.message);
        }
    }

  public override void set_up ()
    {
      base.set_up ();
      this.create_backend ();
    }

  /**
   * Virtual method to create and set up the Tracker backend.
   * Called from set_up(); may be overridden to not create the backend,
   * or to create it but not set it up.
   *
   * Subclasses may chain up, but are not required to so.
   */
  public virtual void create_backend ()
    {
      this.tracker_backend = new TrackerTest.Backend ();
      ((!) this.tracker_backend).set_up ();
    }

  public override void tear_down ()
    {
      if (this.tracker_backend != null)
        {
          ((!) this.tracker_backend).tear_down ();
        }

      /* Ensure that all pending BlueZ operations are complete.
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
