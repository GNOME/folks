/*
 * Copyright (C) 2011 Collabora Ltd.
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
 * Authors: Guillaume Desmottes <guillaume.desmottes@collabora.co.uk>
 *          Philip Withnall <philip@tecnocode.co.uk>
 */

using Gee;
using Folks;

public class InitTests : TpfTest.MixedTestCase
{
  public InitTests ()
    {
      base ("Init");

      /* Set up the tests */
      this.add_test ("looped", this.test_looped);
      this.add_test ("individual-count", this.test_individual_count);
    }

  public override void set_up_kf ()
    {
      /* we do this in the individual tests */
    }

  public override void set_up_tp ()
    {
      /* we do the account creation in the individual tests */
      ((!) this.tp_backend).set_up ();
    }

  /* Prepare a load of aggregators in a tight loop, without waiting for any of
   * the prepare() calls to finish. Since the aggregators share a common
   * BackendStore, this tests the mutual exclusion of prepare() methods in the
   * backends. See: bgo#665728. */
  public void test_looped ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      ((!) this.kf_backend).set_up ("");

      var tp_backend = (!) this.tp_backend;
      void* account1_handle = tp_backend.add_account ("protocol",
          "me@example.com", "cm", "account");
      void* account2_handle = tp_backend.add_account ("protocol",
          "me2@example.com", "cm", "account2");

      /* Wreak havoc. */
      for (uint i = 0; i < 10; i++)
        {
          var aggregator = IndividualAggregator.dup ();
          aggregator.prepare.begin (); /* Note: We don't yield for this to complete */
          aggregator = null;
        }

      TestUtils.loop_run_with_timeout (main_loop, 5);

      /* Clean up for the next test */
      tp_backend.remove_account (account2_handle);
      tp_backend.remove_account (account1_handle);
    }

  /* Prepare an aggregator and wait for quiescence, then count how many
   * individuals it contains. Loop and do the same thing again, then compare
   * the numbers of individuals and their IDs. Do this several times.
   *
   * This tests that the preparation code in IndividualAggregator can handle
   * Backends and PersonaStores which have been prepared before the aggregator
   * was created. To a lesser extent, it also tests that the aggregation code
   * is deterministic. See: bgo#667410. */
  public void test_individual_count ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      ((!) this.kf_backend).set_up (
          "[0]\n" +
          "msn=foo@hotmail.com\n" +
          "[1]\n" +
          "__alias=Bar McBadgerson\n" +
          "jabber=bar@jabber.org\n");

      var tp_backend = (!) this.tp_backend;
      void* account1_handle = tp_backend.add_account ("protocol",
          "me@example.com", "cm", "account");
      void* account2_handle = tp_backend.add_account ("protocol",
          "me2@example.com", "cm", "account2");

      /* Run the test loop. */
      Idle.add (() =>
        {
          this._test_individual_count_loop.begin ((obj, res) =>
            {
              this._test_individual_count_loop.end (res);
              main_loop.quit ();
            });

          return false;
        });

      main_loop.run ();

      /* Clean up for the next test */
      tp_backend.remove_account (account2_handle);
      tp_backend.remove_account (account1_handle);
    }

  private async void _test_individual_count_loop ()
    {
      string[]? previous_individual_ids = null;

      for (uint i = 0; i < 10; i++)
        {
          var aggregator = IndividualAggregator.dup ();

          try
            {
              yield TestUtils.aggregator_prepare_and_wait_for_quiescence (
                  aggregator);
            }
          catch (GLib.Error e1)
            {
              GLib.critical ("Error preparing aggregator: %s", e1.message);
            }

          if (previous_individual_ids == null)
            {
              /* First iteration; store the set of IDs. */
              previous_individual_ids = aggregator.individuals.keys.to_array ();
            }
          else
            {
              /* Compare this set to the previous aggregator's set. */
              debug ("%u vs %u individuals:", previous_individual_ids.length,
                  aggregator.individuals.size);
              assert (previous_individual_ids.length ==
                  aggregator.individuals.size);
              assert (aggregator.individuals.size > 0);

              foreach (var id in previous_individual_ids)
                {
                  debug ("  %s", id);
                  assert (aggregator.individuals.has_key (id) == true);
                }
            }

          /* Destroy the aggregator and loop. */
          aggregator = null;
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new InitTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
