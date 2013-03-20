/*
 * Copyright (C) 2011 Collabora Ltd.
 * Copyright (C) 2012 Philip Withnall
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Travis Reitter <travis.reitter@collabora.com>
 *          Philip Withnall <philip@tecnocode.co.uk>
 *
 */

using Folks;
using GLib;

public class Folks.TestUtils
{
  /* Implemented in C */
  [CCode (cname = "haze_remove_directory",
          cheader_filename = "haze-remove-directory.h")]
  public extern static bool remove_directory_recursively (string path);

  /**
   * Apply an arbitrary fudge factor to the timeout, which might be
   * appropriate for any debuggers or other slow wrappers we're using.
   *
   * @param timeout A timeout in any units
   * @return A revised timeout in the same units
   */
  public static int multiply_timeout (int timeout)
    {
      int result = timeout;

      if (Environment.get_variable ("FOLKS_TEST_VALGRIND") != null)
        {
          result *= 10;
        }

      if (Environment.get_variable ("FOLKS_TEST_CALLGRIND") != null)
        {
          result *= 10;
        }

      return result;
    }

  /**
   * Run //loop// with a timeout. Something should call ``loop.quit()``
   * before the timeout is reached. If not, a fatal error occurs.
   *
   * @param loop A main loop.
   * @param timeout A timeout, initially in seconds, defaulting to long
   *    enough to do something "reasonably fast". It will be adjusted with
   *    multiply_timeout() before use.
   */
  public static void loop_run_with_timeout (MainLoop loop, int timeout = 5)
    {
      var source = new TimeoutSource.seconds (
          TestUtils.multiply_timeout (timeout));
      source.set_callback (() => { error ("Timed out"); });
      source.attach (loop.get_context ());

      loop.run ();

      source.destroy ();
    }

  /**
   * Run //loop// with a timeout. Something should call ``loop.quit()``
   * before the timeout is reached. If not, the timeout callback will do so.
   *
   * This function is a bad idea: we don't want things to run for an arbitrary
   * time. Use loop_run_with_timeout() instead.
   *
   * FIXME: Remove this when it has no more callers.
   *
   * @param loop A main loop.
   * @param timeout A timeout, initially in seconds, defaulting to long
   *    enough to do something "reasonably fast". It will be adjusted with
   *    multiply_timeout() before use.
   */
  [Deprecated (replacement = "loop_run_with_timeout")]
  public static void loop_run_with_non_fatal_timeout (MainLoop loop,
      int timeout = 3)
    {
      var source = new TimeoutSource.seconds (
          TestUtils.multiply_timeout (timeout));
      source.set_callback (() =>
        {
          loop.quit ();
          return false;
        });
      source.attach (loop.get_context ());

      loop.run ();

      source.destroy ();
    }

  /**
   * Compare the content of two {@link LoadableIcon}s for equality.
   *
   * This is in contrast to {@link Icon.equal}, which returns ``false`` for
   * identical icons stored in different subclasses or in different storage
   * locations.
   *
   * This function is particularly useful for tests which compare an avatar set
   * on an {@link AvatarDetails}'s with that object's final avatar, since it may
   * be stored in a location in the avatar cache.
   *
   * @param a the first icon
   * @param b the second icon
   * @param size the size at which to compare the icons
   * @return ``true`` if the instances are equal, ``false`` otherwise
   */
  public static async bool loadable_icons_content_equal (LoadableIcon a,
      LoadableIcon b,
      int icon_size)
    {
      bool retval = false;

      if (a == b)
        return true;

      if (a != null && b != null)
        {
          try
            {
              string a_type;
              var a_input = yield a.load_async (icon_size, null, out a_type);
              string b_type;
              var b_input = yield b.load_async (icon_size, null, out b_type);

              /* arbitrary value */
              size_t bufsize = 2048;
              var a_data = new uint8[bufsize];
              var b_data = new uint8[bufsize];

              /* assume equal until proven otherwise */
              retval = true;
              size_t a_read_size = -1;
              do
                {
                  a_read_size = yield a_input.read_async (a_data);
                  var b_read_size = yield b_input.read_async (b_data);

                  if (a_read_size != b_read_size ||
                      Memory.cmp (a_data, b_data, a_read_size) != 0)
                    {
                      retval = false;
                      break;
                    }
                }
              while (a_read_size > 0);

              yield a_input.close_async ();
              yield b_input.close_async ();
            }
          catch (GLib.Error e1)
            {
              retval = false;
              warning ("Failed to read loadable icon for comparison: %s",
                  e1.message);
            }
        }

      return retval;
    }

  /**
   * Prepare a backend and wait for it to reach quiescence.
   *
   * This will prepare the given {@link Backend} then yield until it reaches
   * quiescence. No timeout is used, so if the backend never reaches quiescence,
   * this function will never return; callers must add their own timeout to
   * avoid this if necessary.
   *
   * When this returns, the backend is guaranteed to be quiescent.
   *
   * @param backend the backend to prepare
   */
  public static async void backend_prepare_and_wait_for_quiescence (
      Backend backend) throws GLib.Error
    {
      var has_yielded = false;
      var signal_id = backend.notify["is-quiescent"].connect ((obj, pspec) =>
        {
          if (has_yielded == true)
            {
              TestUtils.backend_prepare_and_wait_for_quiescence.callback ();
            }
        });

      try
        {
          yield backend.prepare ();

          if (backend.is_quiescent == false)
            {
              has_yielded = true;
              yield;
            }
        }
      finally
        {
          backend.disconnect (signal_id);
          assert (backend.is_quiescent == true);
        }
    }

  /**
   * Prepare an aggregator and wait for it to reach quiescence.
   *
   * This will prepare the given {@link IndividualAggregator} then yield until
   * it reaches quiescence. No timeout is used, so if the aggregator never
   * reaches quiescence, this function will never return; callers must add their
   * own timeout to avoid this if necessary.
   *
   * When this returns, the aggregator is guaranteed to be quiescent.
   *
   * @param aggregator the aggregator to prepare
   */
  public static async void aggregator_prepare_and_wait_for_quiescence (
      IndividualAggregator aggregator) throws GLib.Error
    {
      var has_yielded = false;
      var signal_id = aggregator.notify["is-quiescent"].connect ((obj, pspec) =>
        {
          if (has_yielded == true)
            {
              TestUtils.aggregator_prepare_and_wait_for_quiescence.callback ();
            }
        });

      try
        {
          yield aggregator.prepare ();

          if (aggregator.is_quiescent == false)
            {
              has_yielded = true;
              yield;
            }
        }
      finally
        {
          aggregator.disconnect (signal_id);
          assert (aggregator.is_quiescent == true);
        }
    }

  /**
   * Run a helper executable.
   *
   * @param argv Arguments for the executable. The first is the path of
   *  the executable itself, relative to ${builddir}/tests.
   * @param capture_stdout If non-null, the executable's standard output is
   *  placed here. If null, the executable's standard output goes to the
   *  same place as the test's standard output.
   */
  public static void run_test_helper_sync (string[] argv,
      out string capture_stdout = null) throws GLib.Error
    {
      string execdir;

      if (Environment.get_variable ("FOLKS_TESTS_INSTALLED") != null)
        {
          execdir = BuildConf.PKGLIBEXECDIR + "/tests";
        }
      else
        {
          execdir = BuildConf.ABS_TOP_BUILDDIR + "/tests";
        }

      var argv_ = argv[0:argv.length];
      argv_[0] = execdir + "/" + argv_[0];

      int exit_status = -1;
      Process.spawn_sync (null /* cwd */,
          argv_,
          null /* envp */,
          0 /* flags */,
          null /* child setup */,
          out capture_stdout,
          null /* do not capture stderr */,
          out exit_status);

      Process.check_exit_status (exit_status);
    }

  /**
   * Return the path to a test file that is distributed in the source tarball
   * and, if installed, is installed into ${pkgdatadir}/tests.
   *
   * @param filename A filename relative to ${top_srcdir}/tests
   *  or ${pkgdatadir}/tests (or equivalently, ${datadir}/folks/tests).
   */
  public static string get_source_test_data (string filename)
    {
      if (Environment.get_variable ("FOLKS_TESTS_INSTALLED") != null)
        {
          return BuildConf.PACKAGE_DATADIR + "/tests/" + filename;
        }
      else
        {
          return BuildConf.ABS_TOP_SRCDIR + "/tests/" + filename;
        }
    }

  /**
   * Return the path to a test file that is built by "make"
   * and, if installed, is installed into ${pkgdatadir}/tests.
   *
   * @param filename A filename relative to ${top_builddir}/tests
   *  or ${pkgdatadir}/tests (or equivalently, ${datadir}/folks/tests).
   */
  public static string get_built_test_data (string filename)
    {
      if (Environment.get_variable ("FOLKS_TESTS_INSTALLED") != null)
        {
          return BuildConf.PACKAGE_DATADIR + "/tests/" + filename;
        }
      else
        {
          return BuildConf.ABS_TOP_BUILDDIR + "/tests/" + filename;
        }
    }
}
