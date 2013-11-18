/*
 * Copyright © 2013 Intel Corporation
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
 * Authors:
 *    Simon McVittie <simon.mcvittie@collabora.co.uk>
 */

using Folks;

/**
 * helper-prepare-aggregator [--print-an-individual-id] [--print-a-persona-uid]
 *
 * Prepare a Folks IndividualAggregator and iterate through all individuals,
 * emulating an "ordinary" Folks client application like gnome-contacts.
 *
 * If --print-an-individual-id is given, output a representative individual's
 * globally-unique identifier (Individual.id) to stdout. This can be used
 * as input for a search, to benchmark how long it takes to search for a
 * representative individual.
 *
 * If --print-a-persona-uid is given, output the globally-unique identifier
 * (Persona.uid) of a representative one of that individual's personas
 * to stdout. This can be used as input for a search, to benchmark how long
 * it takes to search for a representative persona.
 *
 * The Individual chosen is the one halfway through iteration, in an attempt
 * to avoid pathologically good or bad performance. Similarly, the Persona
 * chosen is the one halfway through when iterating that Individual's
 * personas.
 */
public class Main
{
  private const uint _TIMEOUT = 20; /* seconds */

  private static bool _print_an_individual_id = false;
  private static bool _print_a_persona_uid = false;

  private const GLib.OptionEntry[] _options = {
      { "print-a-persona-uid", 0, 0, OptionArg.NONE,
          ref Main._print_a_persona_uid,
          "Print a more or less arbitrary Persona UID", null },
      { "print-an-individual-id", 0, 0, OptionArg.NONE,
          ref Main._print_an_individual_id,
          "Print a more or less arbitrary Individual ID", null },
      { null }
  };

  public static int main (string[] args)
    {
      Intl.setlocale (LocaleCategory.ALL, "");

      if (Environment.get_variable ("FOLKS_TESTS_SANDBOXED_DBUS") != "no-services" ||
          Environment.get_variable ("FOLKS_BACKENDS_ALLOWED") != "eds" ||
          Environment.get_variable ("FOLKS_PRIMARY_STORE") == null)
        error ("e-d-s helpers must be run in a private D-Bus session with " +
            "e-d-s services");

      try
        {
          var context = new OptionContext ("- Create many e-d-s contacts");
          context.set_help_enabled (true);
          context.add_main_entries (Main._options, null);
          context.parse (ref args);
        }
      catch (OptionError e)
        {
          stderr.printf ("Error parsing arguments: %s\n", e.message);
          return 2;
        }

      var loop = new MainLoop (null, false);
      AsyncResult? result = null;
      Main._main_async.begin ((nil, res) =>
        {
          result = res;
          loop.quit ();
        });

      TestUtils.loop_run_with_timeout (loop, 60);

      try
        {
          Main._main_async.end ((!) result);
        }
      catch (Error e)
        {
          error ("%s #%d: %s", e.domain.to_string (), e.code, e.message);
        }

      return 0;
    }

  public static async void _main_async () throws GLib.Error
    {
      /* g_log() can print to stdout (if the level is less than MESSAGE)
       * which would spoil our machine-readable output, so we need to
       * remember the original stdout, then make stdout a copy of stderr.
       *
       * Analogous to "3>&1 >&2" in a shell. */
      var original_stdout = FileStream.fdopen (Posix.dup (1), "w");
      assert (original_stdout != null);
      if (Posix.dup2 (2, 1) != 1)
        error ("dup2(stderr, stdout) failed: %s", GLib.strerror (GLib.errno));

      message ("running helper-prepare-aggregator");

      Test.timer_start ();

      message ("%.6f Setting up test backend", Test.timer_elapsed ());

      var store = BackendStore.dup ();

      yield store.prepare ();

      yield store.load_backends ();

      var eds = store.dup_backend_by_name ("eds");
      assert (eds != null);

      message ("%.6f Waiting for EDS backend", Test.timer_elapsed ());

      yield TestUtils.backend_prepare_and_wait_for_quiescence ((!) eds);

      message ("%.6f Waiting for aggregator", Test.timer_elapsed ());
      var aggregator = IndividualAggregator.dup ();
      yield TestUtils.aggregator_prepare_and_wait_for_quiescence (aggregator);

      var map = aggregator.individuals;
      message ("%.6f Aggregated into %d individuals", Test.timer_elapsed (),
          map.size);

      var iter = map.map_iterator ();
      int i = 0;

      while (iter.next ())
        {
          var individual = iter.get_value ();

          debug ("%s → %s", iter.get_key (), individual.full_name);

          /* We use the individual ID that's halfway through in iteration
           * order, in the hope that that'll avoid pathologically good or bad
           * performance. */
          if (Main._print_an_individual_id && i == map.size / 2)
            {
              message ("choosing individual %s - %s\n", individual.id,
                  iter.get_key ());
              original_stdout.printf ("%s\n", iter.get_key ());
            }

          if (Main._print_a_persona_uid && i == map.size / 2)
            {
              var personas = individual.personas;
              int j = 0;

              foreach (var persona in personas)
                {
                  /* We use the persona that's halfway through in iteration
                   * order, for the same reason. */
                  if (j == personas.size / 2)
                    {
                      message ("choosing persona %s\n", persona.uid);
                      original_stdout.printf ("%s\n", persona.uid);
                    }

                  j++;
                }
            }

          i++;
        }
    }
}
