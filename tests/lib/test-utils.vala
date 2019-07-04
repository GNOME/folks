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
using Gee;

public class Folks.TestUtils
{
  /* Implemented in C */
  [CCode (cname = "haze_remove_directory")]
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
              error ("Failed to read loadable icon for comparison: %s",
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
   * Prepare an aggregator and wait for the given personas to be added to it.
   *
   * This will prepare the given {@link IndividualAggregator} then yield until
   * all of the personas listed in ``expected_persona_names`` are added to it.
   * Each of the personas must be added in its own {@link Individual} (i.e. no
   * personas may be linked) and only additions can occur — no personas may be
   * removed. Accordingly, this function is intended for testing the behaviour
   * of a single {@link PersonaStore} without linking.
   *
   * No timeout is used, so if the aggregator never adds all the expected
   * personas, this function will never return; callers must add their own
   * timeout to avoid this if necessary. On return from this function, all of
   * the given names are guaranteed to exist in the aggregator.
   *
   * The names in ``expected_persona_names`` must be those appearing in the
   * {@link NameDetails.full_name} property of the personas (and hence of the
   * individuals).
   *
   * When this returns, the aggregator is //not// guaranteed to be quiescent.
   *
   * @param aggregator the aggregator to prepare
   * @param expected_persona_names set of full names of the expected personas
   * @throws GLib.Error if preparing the aggregator failed
   *
   * @since 0.9.7
   */
  public static async void aggregator_prepare_and_wait_for_individuals (
      IndividualAggregator aggregator, string[] expected_persona_names)
          throws GLib.Error
    {
      var expected = new HashSet<string> ();
      var has_yielded = false;

      foreach (var name in expected_persona_names)
        {
          debug ("Waiting for ‘%s’", name);
          expected.add (name);
        }

      /* Set up the aggregator */
      var signal_id = aggregator.individuals_changed_detailed.connect (
          (changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          foreach (Individual i in added)
            {
              assert (i != null);
              assert (i.personas.size == 1);

              var name_details = i as NameDetails;
              assert (name_details != null);
              expected.remove (name_details.full_name);

              debug ("Saw individual ‘%s’", name_details.full_name);
            }

          assert (removed.size == 1);

          foreach (var i in removed)
              assert (i == null);

          /* Finished? */
          if (expected.size == 0 && has_yielded == true)
              TestUtils.aggregator_prepare_and_wait_for_individuals.callback ();
        });

      try
        {
          yield aggregator.prepare ();

          if (expected.size != 0)
            {
              has_yielded = true;
              yield;
            }
        }
      finally
        {
          aggregator.disconnect (signal_id);
          assert (expected.size == 0);
        }
    }

  /**
   * Wait for the given personas to be added to or removed from an aggregator.
   *
   * This will yield until all of the personas listed in
   * ``expected_added_persona_names`` are added to the aggregator; or until all
   * of the personas listed in ``expected_removed_persona_names`` are removed
   * from it. Only one of the two arrays may be non-empty; this method does not
   * currently implement checking of complex individual change notifications.
   *
   * No timeout is used, so if the aggregator never adds or removes all the
   * expected personas, this function will never return; callers must add their
   * own timeout to avoid this if necessary. On return from this function, all
   * of the given names are guaranteed to exist in the aggregator.
   *
   * The names in ``expected_added_persona_names`` and
   * ``expected_removed_persona_names`` must be those appearing in the
   * {@link NameDetails.full_name} property of the personas (and hence of the
   * individuals).
   *
   * @param aggregator the aggregator to check
   * @param expected_added_persona_names set of full names of the expected
   * personas to be added
   * @param expected_removed_persona_names set of full names of the expected
   * personas to be removed
   *
   * @since 0.9.7
   */
  public static async void aggregator_wait_for_individuals (
      IndividualAggregator aggregator, string[] expected_added_persona_names,
      string[] expected_removed_persona_names)
    {
      /* Currently only support waiting for all additions or all removals. */
      assert (expected_added_persona_names.length == 0 ||
              expected_removed_persona_names.length == 0);

      var expected_added = new HashSet<string> ();
      var expected_removed = new HashSet<string> ();

      foreach (var name in expected_added_persona_names)
          expected_added.add (name);
      foreach (var name in expected_removed_persona_names)
          expected_removed.add (name);

      /* Set up the aggregator */
      var signal_id = aggregator.individuals_changed_detailed.connect (
          (changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          foreach (Individual i in added)
            {
              if (expected_added.size == 0)
                {
                  assert (i == null);
                  break;
                }

              assert (i != null);

              var name_details = i as NameDetails;
              assert (name_details != null);
              expected_added.remove (name_details.full_name);
            }

          foreach (var i in removed)
            {
              if (expected_removed.size == 0)
                {
                  assert (i == null);
                  break;
                }

              assert (i != null);

              var name_details = i as NameDetails;
              assert (name_details != null);
              expected_removed.remove (name_details.full_name);
            }


          /* Finished? */
          if (expected_added.size == 0 && expected_removed.size == 0)
              TestUtils.aggregator_wait_for_individuals.callback ();
        });

      yield;

      aggregator.disconnect (signal_id);
      assert (expected_added.size == 0 && expected_removed.size == 0);
    }

  /**
   * Synchronously prepare an aggregator and wait for the given personas to be
   * added to it.
   *
   * This is a wrapper around
   * {@link TestUtils.aggregator_prepare_and_wait_for_individuals} and
   * {@link TestUtils.loop_run_with_timeout} which creates a main loop and runs
   * it until the given ``expected_persona_names`` are added to the
   * ``aggregator``. If an error occurs, an error message will be printed and
   * the program will abort.
   *
   * If ``timeout`` is specified, it will be passed to
   * {@link TestUtils.loop_run_with_timeout} as the test run timeout.
   *
   * See the documentation for
   * {@link TestUtils.aggregator_prepare_and_wait_for_individuals} for more
   * information.
   *
   * @param aggregator the aggregator to prepare
   * @param expected_persona_names set of full names of the expected personas
   *
   * @since 0.9.7
   */
  public static void aggregator_prepare_and_wait_for_individuals_sync_with_timeout (
      IndividualAggregator aggregator, string[] expected_persona_names,
      int timeout = 5)
    {
      var main_loop = new GLib.MainLoop (null, false);

      TestUtils.aggregator_prepare_and_wait_for_individuals.begin (aggregator,
          expected_persona_names, (o, r) =>
        {
          try
            {
              TestUtils.aggregator_prepare_and_wait_for_individuals.end (r);
            }
          catch (GLib.Error e1)
            {
              error ("Error preparing aggregator: %s", e1.message);
            }

          main_loop.quit ();
        });

      TestUtils.loop_run_with_timeout (main_loop, timeout);
    }

  /**
   * Get a named individual from an {@link IndividualAggregator}.
   *
   * This returns the {@link Individual} with {@link NameDetails.full_name}
   * equal to ``full_name`` from the given ``aggregator``.
   *
   * If multiple individuals exist with the given name, the first one found is
   * returned. It is expected that tests will be constructed so that full names
   * are unique, however.
   *
   * If no individual is found with the given name, an assertion fails and the
   * program aborts.
   *
   * @param aggregator aggregator to retrieve the value from
   * @param full_name name of the individual to retrieve
   * @return individual with the given name
   *
   * @since 0.9.7
   */
  public static Individual get_individual_by_name (
      IndividualAggregator aggregator, string full_name)
    {
      foreach (var v in aggregator.individuals.values)
        {
          if (v.full_name == full_name)
              return v;
        }

      assert_not_reached ();
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
          execdir = BuildConf.INSTALLED_TESTS_DIR + "/";
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
   * and, if installed, is installed into ${installed_tests_dir}.
   *
   * @param filename A filename relative to ${top_srcdir}/tests
   *  or ${installed_tests_dir}.
   */
  public static string get_source_test_data (string filename)
    {
      if (Environment.get_variable ("FOLKS_TESTS_INSTALLED") != null)
        {
          return BuildConf.INSTALLED_TESTS_DIR + "/" + filename;
        }
      else
        {
          return BuildConf.ABS_TOP_SRCDIR + "/tests/" + filename;
        }
    }

  /**
   * Return the path to a test file that is built by "make"
   * and, if installed, is installed into ${installed_tests_dir}.
   *
   * @param filename A filename relative to ${top_builddir}/tests
   *  or ${installed_tests_dir}.
   */
  public static string get_built_test_data (string filename)
    {
      if (Environment.get_variable ("FOLKS_TESTS_INSTALLED") != null)
        {
          return BuildConf.INSTALLED_TESTS_DIR + "/" + filename;
        }
      else
        {
          return BuildConf.ABS_TOP_BUILDDIR + "/tests/" + filename;
        }
    }

  /**
   * Check that there are no pending events on the given ``context``, and return
   * ``true`` if there are none.
   *
   * @param context A main context, or ``null`` to use the default main context.
   * @returns Whether there are no events pending on the context.
   * @since 0.9.7
   */
  public static bool main_context_is_empty (MainContext? context = null)
    {
      if (context == null)
          context = MainContext.default ();

      return !context.pending ();
    }
}
