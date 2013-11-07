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
 * 	Julien Peeters <contact@julienpeeters.fr>
 * 	Simon McVittie <simon.mcvittie@collabora.co.uk>
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
  private GLib.TestSuite _suite;
  public delegate void TestMethod ();

  public TestCase (string name)
    {
      Intl.setlocale (LocaleCategory.ALL, "");

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

      if (Environment.get_variable ("FOLKS_TESTS_INSTALLED") == null)
        {
          string[] locations = {
              Folks.BuildConf.ABS_TOP_BUILDDIR + "/backends/key-file/.libs/key-file.so",
              Folks.BuildConf.ABS_TOP_BUILDDIR + "/backends/dummy/.libs/dummy.so",
          };

          if (Folks.BuildConf.HAVE_EDS)
            locations += Folks.BuildConf.ABS_TOP_BUILDDIR + "/backends/eds/.libs/eds.so";

          if (Folks.BuildConf.HAVE_LIBSOCIALWEB)
            locations += Folks.BuildConf.ABS_TOP_BUILDDIR + "/backends/libsocialweb/.libs/libsocialweb.so";

          if (Folks.BuildConf.HAVE_OFONO)
            locations += Folks.BuildConf.ABS_TOP_BUILDDIR + "/backends/ofono/.libs/ofono.so";

          if (Folks.BuildConf.HAVE_TELEPATHY)
            locations += Folks.BuildConf.ABS_TOP_BUILDDIR + "/backends/telepathy/.libs/telepathy.so";

          if (Folks.BuildConf.HAVE_TRACKER)
            locations += Folks.BuildConf.ABS_TOP_BUILDDIR + "/backends/tracker/.libs/tracker.so";

          Environment.set_variable ("FOLKS_BACKEND_PATH",
              string.joinv (":", locations), true);
        }

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
   *
   * FIXME: Subclasses relying on being called by with-session-bus-*.sh
   * may override this method to return null, although we should really
   * stop doing that.
   */
  public virtual string? create_transient_dir ()
    {
      unowned string tmp = Environment.get_tmp_dir ();
      string transient = "%s/folks-test.XXXXXX".printf (tmp);

      if (GLib.DirUtils.mkdtemp (transient) == null)
        error ("unable to create temporary directory in '%s': %s",
            tmp, GLib.strerror (GLib.errno));

      debug ("setting up in transient directory %s", transient);

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

      /* Unset some things we don't want to inherit. In particular,
       * Tracker might try to index XDG_*_DIR, which we don't want. */
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
   * A private D-Bus session, normally created by private_bus_up()
   * from the constructor.
   *
   * This is per-process, not per-test, because the session bus's
   * address is frequently treated as process-global (for instance,
   * libdbus will cache a single session bus connection indefinitely).
   */
  public GLib.TestDBus? test_dbus = null;

  /**
   * If true, libraries involved in this test use dbus-1 (or dbus-glib-1)
   * so we need to turn off its exit-on-disconnect feature.
   *
   * FIXME: when our dependencies stop needing this, this whole feature
   * can be removed (GNOME#696177).
   */
  public virtual bool uses_dbus_1
    {
      get
        {
          return false;
        }
    }

  /**
   * Start the temporary D-Bus session.
   *
   * This is per-process, not per-test, for the reasons mentioned for
   * //test_dbus//.
   */
  public virtual void private_bus_up ()
    {
      Environment.unset_variable ("DBUS_SESSION_BUS_ADDRESS");
      Environment.unset_variable ("DBUS_SESSION_BUS_PID");

      this.test_dbus = new GLib.TestDBus (GLib.TestDBusFlags.NONE);
      var test_dbus = (!) this.test_dbus;

      test_dbus.up ();

      assert (Environment.get_variable ("DBUS_SESSION_BUS_ADDRESS") != null);

      /* Tell subprocesses that we're running in a private D-Bus
       * session, so certain operations that would otherwise be dangerous
       * are OK. */
      Environment.set_variable ("FOLKS_TESTS_SANDBOXED_DBUS", "no-services",
          true);
    }

  public void register ()
    {
      TestSuite.get_root ().add_suite (this._suite);
    }

  public void add_test (string name, TestMethod test)
    {
      this._suite.add (add_test_helper (name, test));
    }

  /* implemented in test-case-helper.c */
  internal extern GLib.TestCase add_test_helper (string name, TestMethod test);

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
    }

  internal extern static void _dbus_1_set_no_exit_on_disconnect ();

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
      if (this.uses_dbus_1)
        TestCase._dbus_1_set_no_exit_on_disconnect ();

      if (this.test_dbus != null)
        {
          ((!) this.test_dbus).down ();
          this.test_dbus = null;
        }

      if (this._transient_dir != null)
        {
          unowned string dir = (!) this._transient_dir;
          Folks.TestUtils.remove_directory_recursively (dir);
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
          GLib.set_printerr_handler (LogAdaptor._printerr_func_stack_trace);
          Log.set_default_handler (LogAdaptor._log_func_stack_trace);
        }

      private static void _printerr_func_stack_trace (string? text)
        {
          if (text == null || str_equal (text, ""))
            return;

          stderr.printf (text);

          /* Print a stack trace since we've hit some major issue */
          GLib.on_error_stack_trace ("libtool --mode=execute gdb");
        }

      private static void _log_func_stack_trace (string? log_domain,
          LogLevelFlags log_levels,
          string message)
        {
          Log.default_handler (log_domain, log_levels, message);

          /* Print a stack trace for any message at the warning level or above
           */
          if ((log_levels &
              (LogLevelFlags.LEVEL_WARNING | LogLevelFlags.LEVEL_ERROR |
                  LogLevelFlags.LEVEL_CRITICAL))
              != 0)
            {
              GLib.on_error_stack_trace ("libtool --mode=execute gdb");
            }
        }
    }
}
