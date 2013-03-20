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
      LogAdaptor.set_up ();
      this._suite = new GLib.TestSuite (name);

      this.private_bus_up ();

      /* By default, no backend is allowed. Subclasses must override. */
      Environment.set_variable ("FOLKS_BACKENDS_ALLOWED", "", true);
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
      this.test_dbus = new GLib.TestDBus (GLib.TestDBusFlags.NONE);
      var test_dbus = (!) this.test_dbus;

      test_dbus.up ();

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
  private extern GLib.TestCase add_test_helper (string name, TestMethod test);

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
