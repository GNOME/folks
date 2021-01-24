/* testcase.vala
 *
 * Copyright (C) 2009 Julien Peeters
 * Copyright (C) 2013 Intel Corporation
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
 *   Julien Peeters <contact@julienpeeters.fr>
 *   Simon McVittie <simon.mcvittie@collabora.co.uk>
 *
 * Adapted from libgee/tests/testcase.vala.
 */

/**
 * A test case for Folks, containing one or more individual tests.
 *
 * The constructor configures Folks to disallow all backends, via
 * ``FOLKS_BACKENDS_ALLOWED``. Subclasses are expected to reset
 * this variable to a suitable value in their constructors or
 * set_up() methods.
 */
public abstract class Folks.TestCase : Object
{
  public static bool in_final_tear_down = false;

  private GLib.TestSuite _suite;
  public delegate void TestMethod ();

  protected TestCase (string name)
    {
      Intl.setlocale (LocaleCategory.ALL, "");

      /* Enable all debug output from libfolks. If the user’s already set
       * those variables, though, don’t overwrite them. */
      Environment.set_variable ("G_MESSAGES_DEBUG", "all", false);

      /* Turn off use of gvfs. If using GTestDBus it's unavailable,
       * and if not it's pointless: all we need is the local filesystem. */
      Environment.set_variable ("GIO_USE_VFS", "local", true);

      /* If run from gnome-terminal 3.8 or a similar activatable service,
       * forget the "starter bus" in favour of DBUS_SESSION_BUS_ADDRESS.
       * FIXME: GTestDBus should do this for us (GNOME #697348). */
      Environment.unset_variable ("DBUS_STARTER_ADDRESS");
      Environment.unset_variable ("DBUS_STARTER_BUS_TYPE");

      LogAdaptor.set_up ();
      this._suite = new GLib.TestSuite (name);

      this._transient_dir = this.create_transient_dir ();
      this.private_bus_up ();

      /* By default, no backend is allowed. Subclasses must override. */
      Environment.set_variable ("FOLKS_BACKENDS_ALLOWED", "", true);
    }

  private string? _transient_dir = null;
  /**
   * A transient directory normally created in the constructor and deleted
   * in final_tear_down(). This can be used for temporary storage.
   * The environment variables ``XDG_CONFIG_HOME``, ``XDG_DATA_HOME``,
   * ``XDG_CACHE_HOME``, etc. point into it.
   */
  public string transient_dir
    {
      get
        {
          assert (this._transient_dir != null);
          return (!) this._transient_dir;
        }
    }

  /**
   * Create and return a transient directory suitable for use as
   * //transient_dir//. Set environment variables to point into it.
   *
   * This is only called once per process, so that it can be used in
   * environment variables that are cached or otherwise considered to
   * be process-global. As such, all tests in a TestCase share it.
   *
   * Subclasses may override this method to do additional setup
   * (create more subdirectories or set more environment variables).
   */
  public virtual string create_transient_dir ()
    {
      unowned string tmp = Environment.get_tmp_dir ();
      string transient_template = "%s/folks-test.XXXXXX".printf (tmp);

      string transient = GLib.DirUtils.mkdtemp (transient_template);
      if (transient == null)
        error ("Unable to create temporary directory in '%s': %s",
            tmp, GLib.strerror (GLib.errno));

      debug ("Setting up in transient directory %s", transient);

      /* Don't try to use dconf */
      Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);

      /* GLib >= 2.36, and various non-GNOME things, obey this. */
      Environment.set_variable ("HOME", transient, true);
      /* GLib < 2.36 in Debian obeyed this (although upstream GLib < 2.36
       * used the home directory from passwd), so set it too.
       * FIXME: remove this when we depend on 2.36. */
      Environment.set_variable ("G_HOME", transient, true);

      var cache = "%s/.cache".printf (transient);
      Environment.set_variable ("XDG_CACHE_HOME", cache, true);

      if (GLib.DirUtils.create_with_parents (cache, 0700) != 0)
        error ("unable to create '%s': %s",
            cache, GLib.strerror (GLib.errno));

      var config = "%s/.config".printf (transient);
      Environment.set_variable ("XDG_CONFIG_HOME", config, true);

      if (GLib.DirUtils.create_with_parents (config, 0700) != 0)
        error ("unable to create '%s': %s",
            config, GLib.strerror (GLib.errno));

      var local = "%s/.local/share".printf (transient);
      Environment.set_variable ("XDG_DATA_HOME", local, true);

      if (GLib.DirUtils.create_with_parents (local, 0700) != 0)
        error ("unable to create '%s': %s",
            local, GLib.strerror (GLib.errno));

      /* Under systemd user sessions this is meant to define the
       * lifetime of a logged-in-user - the regression tests don't
       * want to be part of this. */
      var runtime = "%s/XDG_RUNTIME_DIR".printf (transient);
      Environment.set_variable ("XDG_RUNTIME_DIR", runtime, true);

      if (GLib.DirUtils.create_with_parents (runtime, 0700) != 0)
        error ("unable to create '%s': %s",
            runtime, GLib.strerror (GLib.errno));

      /* Directories to contain D-Bus service files. */
      var dbus_system = "%s/dbus-1/system-services".printf (transient);

      if (GLib.DirUtils.create_with_parents (dbus_system, 0700) != 0)
        error ("unable to create '%s': %s",
            local, GLib.strerror (GLib.errno));

      var dbus_session = "%s/dbus-1/services".printf (transient);

      if (GLib.DirUtils.create_with_parents (dbus_session, 0700) != 0)
        error ("unable to create '%s': %s",
            local, GLib.strerror (GLib.errno));

      /* Unset some things we don't want to inherit. */
      Environment.unset_variable ("XDG_DESKTOP_DIR");
      Environment.unset_variable ("XDG_DOCUMENTS_DIR");
      Environment.unset_variable ("XDG_DOWNLOAD_DIR");
      Environment.unset_variable ("XDG_MUSIC_DIR");
      Environment.unset_variable ("XDG_PICTURES_DIR");
      Environment.unset_variable ("XDG_PUBLICSHARE_DIR");
      Environment.unset_variable ("XDG_TEMPLATES_DIR");
      Environment.unset_variable ("XDG_VIDEOS_DIR");

      return transient;
    }

  /**
   * Create a D-Bus service file for a python-dbusmock service.
   *
   * Create a service file to allow auto-launching a python-dbusmock service
   * which uses the given ``dbusmock_template_name`` to mock up the service
   * running at ``bus_name`` on the ``bus_type`` bus (which must either be
   * {@link BusType.SYSTEM} or {@link BusType.SESSION}.
   *
   * This requires Python 3 to be installed and available to run as ``python3``
   * somewhere in the system ``PATH``.
   *
   * It will create a temporary log file which python-dbusmock will log to if
   * launched. The name of the log file will be printed to the test logs.
   *
   * The D-Bus service file itself will be created in a subdirectory of
   * {@link TestCase.transient_dir}, which the {@link TestDBus} instance has
   * already been configured to use as a service directory. This requires
   * {@link TestCase.create_transient_dir} to have been called already.
   *
   * @param bus_type the bus the service should be auto-launchable from
   * @param bus_name the well-known bus name used by the service
   * @param dbusmock_template_name name of the python-dbusmock template to use
   *
   * @since 0.9.7
   */
  public void create_dbusmock_service (BusType bus_type, string bus_name,
      string dbusmock_template_name)
    {
      string service_dir;
      switch (bus_type)
        {
          case BusType.SYSTEM:
            service_dir = "system-services";
            break;
          case BusType.SESSION:
            service_dir = "services";
            break;
          case BusType.STARTER:
          case BusType.NONE:
          default:
            assert_not_reached ();
        }

      /* Find where the Python 3 executable is (service files require absolute
       * paths). */
      var python = Environment.find_program_in_path ("python3");
      if (python == null)
        {
          error ("Couldn’t find `python3` in $PATH; can’t run " +
              "python-dbusmock.");
        }

      /* Create a temporary log file for dbusmock to use. This doesn’t need to
       * use mkstemp() because it’s already in a unique temporary directory. */
      var log_file_name =
          Path.build_filename (this.transient_dir,
              "dbusmock-%s-%s-%s.log".printf (service_dir, bus_name,
                  dbusmock_template_name));
      Test.message ("python-dbusmock service ‘%s’ (template ‘%s’) will log " +
          "to ‘%s’.", bus_name, dbusmock_template_name, log_file_name);

      /* Write out the service file for the dbusmock service. */
      var service_file_name =
          Path.build_filename (this.transient_dir, "dbus-1", service_dir,
              dbusmock_template_name + ".service");
      var service_file = ("[D-BUS Service]\n" +
          "Name=%s\n" +
          "Exec=%s -m dbusmock --template %s -l %s\n").printf (bus_name, python,
              dbusmock_template_name, log_file_name);

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

  /**
   * A private D-Bus session, normally created by private_bus_up()
   * from the constructor.
   *
   * This is per-process, not per-test, because the session bus's
   * address is frequently treated as process-global (for instance,
   * libdbus will cache a single session bus connection indefinitely).
   */
  public Folks.TestDBus? test_dbus = null;

  /**
   * A private D-Bus system bus, normally created by private_bus_up() from the
   * constructor.
   *
   * As with {@link TestCase.test_dbus} this is per-process.
   *
   * @since 0.9.7
   */
  public Folks.TestDBus? test_system_dbus = null;

  /**
   * Start the temporary D-Bus session.
   *
   * This is per-process, not per-test, for the reasons mentioned for
   * //test_dbus//.
   *
   * By calling {@link TestCase.create_dbusmock_service} in an overridden
   * version of this method, python-dbusmock services may be set up.
   */
  public virtual void private_bus_up ()
    {
      /* Clear out existing bus variables. */
      Folks.TestDBus.unset ();

      /* Set up the system bus first, then shimmy its address sideways. */
      this.test_system_dbus = new Folks.TestDBus (Folks.TestDBusFlags.SYSTEM_BUS);
      var test_system_dbus = (!) this.test_system_dbus;
      test_system_dbus.add_service_dir (
          this.transient_dir + "/dbus-1/system-services");

      test_system_dbus.up ();

      var system_bus_address = test_system_dbus.get_bus_address ();

      /* Now the session bus. */
      this.test_dbus = new Folks.TestDBus (Folks.TestDBusFlags.NONE);
      var test_dbus = (!) this.test_dbus;
      test_dbus.add_service_dir (this.transient_dir + "/dbus-1/services");

      test_dbus.up ();

      var session_bus_address = test_dbus.get_bus_address ();

      /* Set the bus addresses. We have to do this manually to prevent GTestDBus
       * from unsetting the first bus’ address when starting the second. */
      Environment.set_variable ("DBUS_SYSTEM_BUS_ADDRESS", system_bus_address,
          true);
      Environment.set_variable ("DBUS_SESSION_BUS_ADDRESS", session_bus_address,
          true);

      /* Tell subprocesses that we're running in a private D-Bus
       * session, so certain operations that would otherwise be dangerous
       * are OK. */
      Environment.set_variable ("FOLKS_TESTS_SANDBOXED_DBUS", "no-services",
          true);

      /* Disable the GVFS remote volume monitor so we don’t have to mock the
       * org.gtk.vfs.Daemon D-Bus service. */
      Environment.set_variable ("GVFS_REMOTE_VOLUME_MONITOR_IGNORE", "1", true);
    }

  public void register ()
    {
      TestSuite.get_root ().add_suite (this._suite);
    }

  public void add_test (string name, owned TestMethod test)
    {
      this._suite.add (add_test_helper (name, (owned) test));
    }

  /* implemented in test-case-helper.c */
  internal extern GLib.TestCase add_test_helper (string name,
      owned TestMethod test);

  /**
   * Set up for one test. If you have more than one test, this will
   * be called once per test.
   *
   * Subclasses may override this method. They are expected to chain up
   * as the first thing in their implementation.
   */
  public virtual void set_up ()
    {
    }

  /**
   * Clean up after one test, undoing set_up(). If you have more than
   * one test, this will be called once per test.
   *
   * Subclasses may override this method. They are expected to chain up
   * as the last thing in their implementation.
   */
  public virtual void tear_down ()
    {
      /* Assert there are no events left on the main context. */
      /* FIXME: This causes too many false positive test failures for now.
       * https://bugzilla.gnome.org/show_bug.cgi?id=727700 */
      /* assert (TestUtils.main_context_is_empty ()); */
    }

  /**
   * Clean up after all tests. If you have more than one test case, this
   * will be called once, the last time only. It should undo the
   * constructor, and must be idempotent (i.e. OK to call more than once).
   *
   * Subclasses may override this method. They are expected to chain up
   * as the last thing in their implementation.
   *
   * If there are no reference leaks, this method will be called
   * automatically when the TestCase is destroyed.
   */
  public virtual void final_tear_down ()
    {
      TestCase.in_final_tear_down = true;

      /* FIXME: The EDS tests randomly fail due to race conditions in tearing
       * down the GTestDBus. So avoid that completely, because I’m sick of not
       * being able to release while waiting for a solution to be hammered out
       * for the GTestDBus/weak-ref problem.
       *
       * See:
       *  • https://bugzilla.gnome.org/show_bug.cgi?id=726973
       *  • https://bugzilla.gnome.org/show_bug.cgi?id=729150
       *  • https://bugzilla.gnome.org/show_bug.cgi?id=711807
       *  • https://bugzilla.gnome.org/show_bug.cgi?id=729152
       */
      if (this._transient_dir != null)
        {
          unowned string dir = (!) this._transient_dir;
          Folks.TestUtils.remove_directory_recursively (dir);
        }

      Posix.exit (0);

      if (this.test_dbus != null)
        {
          ((!) this.test_dbus).down ();
          this.test_dbus = null;
        }

      if (this.test_system_dbus != null)
        {
          ((!) this.test_system_dbus).down ();
          this.test_system_dbus = null;
        }
    }

  ~TestCase ()
    {
      this.final_tear_down ();
    }

  private class LogAdaptor
    {
      public LogAdaptor ()
        {
        }

      public static void set_up ()
        {
          Log.set_default_handler (LogAdaptor._log_func_stack_trace);
        }

      private static void _log_func_stack_trace (string? log_domain,
          LogLevelFlags log_levels,
          string message)
        {
          Log.default_handler (log_domain, log_levels, message);

          /* hack: warnings are not fatal while doing final teardown,
           * because lots of things cope poorly with the GTestDBus
           * being forcibly disposed */
          if (TestCase.in_final_tear_down)
            return;
        }
    }
}
