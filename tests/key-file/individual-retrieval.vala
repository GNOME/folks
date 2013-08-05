/*
 * Copyright (C) 2011, 2013 Collabora Ltd.
 * Copyright (C) 2013 Philip Withnall
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
 * Authors: Travis Reitter <travis.reitter@collabora.co.uk>
 *          Philip Withnall <philip@tecnocode.co.uk>
 */

using Gee;
using Folks;
using KfTest;

public class IndividualRetrievalTests : KfTest.TestCase
{
  public IndividualRetrievalTests ()
    {
      base ("IndividualRetrieval");

      this.add_test ("singleton individuals", this.test_singleton_individuals);
      this.add_test ("aliases", this.test_aliases);
    }

  public void test_singleton_individuals ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      this.kf_backend.set_up (
          "[0]\n" +
          "msn=foo@hotmail.com\n" +
          "[1]\n" +
          "__alias=Bar McBadgerson\n" +
          "jabber=bar@jabber.org\n");

      /* Create a set of the individuals we expect to see */
      HashSet<string> expected_individuals = new HashSet<string> ();

      expected_individuals.add ("0");
      expected_individuals.add ("1");

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          foreach (Individual i in added)
            {
              assert (i != null);
              assert (i.personas.size == 1);

              /* Using the display ID is a little hacky, since we strictly
               * shouldn't assume anything about…but for the key-file backend,
               * we know it's equal to the group name. */
              foreach (var persona in i.personas)
                {
                  expected_individuals.remove (persona.display_id);
                }
            }

          assert (removed.size == 1);

          foreach (var i in removed)
            {
              assert (i == null);
            }

          /* Finished? */
          if (expected_individuals.size == 0)
              main_loop.quit ();
        });
      aggregator.prepare.begin ();

      /* Kill the main loop after a few seconds. If there are still individuals
       * in the set of expected individuals, the aggregator has either failed
       * or been too slow (which we can consider to be failure). */
      TestUtils.loop_run_with_timeout (main_loop, 3);

      /* We should have enumerated exactly the individuals in the set */
      assert (expected_individuals.size == 0);

      this.kf_backend.tear_down ();
    }

  public void test_aliases ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      this.kf_backend.set_up (
          "[0]\n" +
          "__alias=Brian Briansson\n" +
          "msn=foo@hotmail.com\n");

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
      uint individuals_changed_count = 0;
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          individuals_changed_count++;

          assert (added.size == 1);
          assert (removed.size == 1);

          /* Check properties */
          foreach (var i in added)
            {
              assert (i.alias == "Brian Briansson");
            }

          foreach (var i in removed)
            {
              assert (i == null);
            }

          /* Finished? */
          if (individuals_changed_count == 1)
              main_loop.quit ();
        });
      aggregator.prepare.begin ();

      /* Kill the main loop after a few seconds. If there are still individuals
       * in the set of expected individuals, the aggregator has either failed
       * or been too slow (which we can consider to be failure). */
      TestUtils.loop_run_with_timeout (main_loop, 3);

      /* We should have enumerated exactly one individual */
      assert (individuals_changed_count == 1);

      this.kf_backend.tear_down ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new IndividualRetrievalTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
