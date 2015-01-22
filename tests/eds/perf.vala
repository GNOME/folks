/*
 * Copyright © 2011 Collabora Ltd.
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
 *    Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *    Simon McVittie <simon.mcvittie@collabora.co.uk>
 */

using Folks;

public class PerfTests : EdsTest.TestCase
{
  public PerfTests ()
    {
      base ("PerfTests");

      this.add_test ("unprepared", this._test);
      this.add_test ("again", this._test);
      this.add_test ("twice", this._test_twice);
      this.add_test ("pre-prepared", this._test_preprepared);

      this.add_test ("pre-prepared-one-individual", this._test_preprepared_one);
      this.add_test ("pre-prepared-one-persona",
          this._test_preprepared_one_persona);

      if (Test.perf () ||
          Environment.get_variable ("FOLKS_TESTS_SLOW") != null)
        {
          this.add_test ("clones", this._test_clones);
          this.add_test ("clones-one-individual", this._test_clones_one);
          this.add_test ("clones-one-persona", this._test_clones_one_persona);
        }
      else
        {
          message ("skipping slow tests, run with -m perf or " +
              "FOLKS_TESTS_SLOW=1 to enable");
        }
    }

  /* Add a bunch of contacts, going behind Folks' back. Do it in a
   * subprocess, so that we ignore it when profiling this process. */
  private void _add_500 ()
    {
      Test.timer_start ();

      try
        {
          Folks.TestUtils.run_test_helper_sync (
              { "eds/helper-create-many-contacts",
                  "-n", "500",
                  "-u", ((!) this.eds_backend).address_book_uid });
        }
      catch (Error e)
        {
          error (e.message);
        }

      message ("%.6f Finished adding contacts", Test.timer_elapsed ());
    }

  public override void set_up ()
    {
      base.set_up ();
      this._add_500 ();
    }

  /* Prepare the individual aggregator and wait for it to quiesce. */
  private async IndividualAggregator _aggregate () throws Error
    {
      Test.timer_start ();

      message ("%.6f Preparing backend store", Test.timer_elapsed ());
      var store = BackendStore.dup ();
      yield store.prepare ();

      message ("%.6f Loading backends", Test.timer_elapsed ());
      yield store.load_backends ();

      var eds = store.dup_backend_by_name ("eds");
      assert (eds != null);

      message ("%.6f Waiting for EDS backend", Test.timer_elapsed ());
      yield TestUtils.backend_prepare_and_wait_for_quiescence ((!) eds);

      message ("%.6f Preparing aggregator", Test.timer_elapsed ());
      var aggregator = IndividualAggregator.dup ();
      yield aggregator.prepare ();

      message ("%.6f Waiting for aggregator", Test.timer_elapsed ());
      yield TestUtils.aggregator_prepare_and_wait_for_quiescence (aggregator);

      return aggregator;
    }

  private IndividualAggregator _run_aggregate ()
    {
      AsyncResult? result = null;
      var loop = new MainLoop (null, false);

      this._aggregate.begin ((obj, res) =>
        {
          result = res;
          loop.quit ();
        });

      TestUtils.loop_run_with_timeout (loop, 60);
      assert (result != null);

      try
        {
          return this._aggregate.end ((!) result);
        }
      catch (Error e)
        {
          error ("%s #%d: %s", e.domain.to_string (), e.code, e.message);
        }
    }

  /* Basic test: prepare the aggregator, then iterate through individuals.
   * Also part of some subsequent tests.
   *
   * This represents a Folks client like gnome-contacts or the Empathy
   * contact list, whose use case is: give me all my contacts as
   * Individuals. */
  private void _test ()
    {
      var aggregator = this._run_aggregate ();

      var map = aggregator.individuals;
      var iter = aggregator.individuals.map_iterator ();

      message ("%.6f Aggregated into %d individuals", Test.timer_elapsed (),
          map.size);

      while (iter.next ())
        debug ("%s → %s", iter.get_key (), iter.get_value ().full_name);

      var elapsed = Test.timer_elapsed ();
      Test.minimized_result (elapsed,
          "%.6f Total time to iterate %d individuals", elapsed, map.size);
    }

  /* Basis for tests that look for one individual.
   *
   * This represents a Folks client that has a stored individual ID
   * and wants to display that one Individiual. */
  private async void _test_one_individual (string id) throws Error
    {
      var aggregator = yield this._aggregate ();
      var map = aggregator.individuals;
      Individual? individual = yield aggregator.look_up_individual (id);

      assert (individual != null);

      message ("%s => %s", id, ((!) individual).full_name);

      var elapsed = Test.timer_elapsed ();
      Test.minimized_result (elapsed,
          "%.6f Total time to find one of %d individuals", elapsed, map.size);
    }

  private void _run_test_one_individual (string id) throws Error
    {
      AsyncResult? result = null;
      var loop = new MainLoop (null, false);

      this._test_one_individual.begin (id, (obj, res) =>
        {
          result = res;
          loop.quit ();
        });

      TestUtils.loop_run_with_timeout (loop, 60);
      assert (result != null);

      this._test_one_individual.end ((!) result);
    }

  /* Basis for tests that look for one Persona.
   *
   * This represents a Folks client that has a stored persona UID,
   * or can derive one from information known to it (e.g. a Telepathy
   * identifier), and wants to display that Persona and its
   * parent Individual. */
  private async void _test_one_persona (string uid) throws Error
    {
      var aggregator = yield this._aggregate ();
      var map = aggregator.individuals;

      message ("%.6f Aggregated into %d individuals", Test.timer_elapsed (),
          map.size);

      /* FIXME: #696215: there really ought to be convenience API for
       * some of this. */
      string backend_name;
      string persona_store_id;
      string persona_id;
      Persona.split_uid (uid, out backend_name, out persona_store_id,
          out persona_id);
      var backend_store = BackendStore.dup ();
      var backend = backend_store.dup_backend_by_name (backend_name);
      assert (backend != null);
      var persona_stores = ((!) backend).persona_stores;
      var persona_store = persona_stores[persona_store_id];
      assert (persona_store != null);
      var personas = ((!) persona_store).personas;

      /* personas is keyed by Persona.iid, which is not the same thing as
       * either Individual.id or Persona.uid.
       *
       * FIXME: surely there ought to be a generic way to do this without
       * iteration? */
      Persona? persona = null;
      var iter = personas.map_iterator ();
      while (iter.next ())
        {
          persona = iter.get_value ();

          if (persona.uid == uid)
            break;
        }

      assert (persona != null);
      var individual = persona.individual;
      assert (individual != null);
      message ("%s is part of individual %s", uid, persona.individual.id);

      var elapsed = Test.timer_elapsed ();
      Test.minimized_result (elapsed,
          "%.6f Total time to find one of %d individuals by persona uid",
          elapsed, map.size);
    }

  private void _run_test_one_persona (string id) throws Error
    {
      AsyncResult? result = null;
      var loop = new MainLoop (null, false);

      this._test_one_persona.begin (id, (obj, res) =>
        {
          result = res;
          loop.quit ();
        });

      TestUtils.loop_run_with_timeout (loop, 60);
      assert (result != null);

      this._test_one_persona.end ((!) result);
    }

  /**
   * Benchmark whether we go any faster when test() is repeated.
   */
  private void _test_twice ()
    {
      this._test ();
      this._test ();
    }

  /**
   * Benchmark how much slower we go when we have many similar (or in this
   * case, identical except for unique identifier) contacts in a backend.
   *
   * This is really pretty slow, so it's only run if either the test
   * was run with -m perf, or FOLKS_TESTS_SLOW is set (because setting
   * environment variables is easier than passing command-line arguments
   * while using Automake).
   */
  private void _test_clones ()
    {
      /* Work with 3 copies of basically the same 500 contacts. */
      this._add_500 ();
      this._add_500 ();
      this._test ();
    }

  /**
   * Benchmark how much faster we go when another process has already prepared
   * our cache for us (assuming we ever implement such a cache).
   */
  private void _test_preprepared ()
    {
      try
        {
          Test.timer_start ();
          Folks.TestUtils.run_test_helper_sync (
              { "eds/helper-prepare-aggregator" });
          message ("%.6f Finished pre-preparation", Test.timer_elapsed ());
        }
      catch (Error e)
        {
          error (e.message);
        }

      this._test ();
    }

  /* test_preprepared() x test_one_individual() */
  private void _test_preprepared_one ()
    {
      try
        {
          string capture;
          Test.timer_start ();
          Folks.TestUtils.run_test_helper_sync (
              { "eds/helper-prepare-aggregator", "--print-an-individual-id" },
              out capture);
          message ("%.6f Finished pre-preparation", Test.timer_elapsed ());

          capture = capture.chomp ();
          this._run_test_one_individual (capture);
        }
      catch (Error e)
        {
          error (e.message);
        }
    }

  /* test_preprepared_one() x test_clones() */
  private void _test_clones_one ()
    {
      this._add_500 ();
      this._add_500 ();
      this._test_preprepared_one ();
    }

  /* test_preprepared() x test_one_persona() */
  private void _test_preprepared_one_persona ()
    {
      try
        {
          string capture;
          Test.timer_start ();
          Folks.TestUtils.run_test_helper_sync (
              { "eds/helper-prepare-aggregator", "--print-a-persona-uid" },
              out capture);
          message ("%.6f Finished pre-preparation", Test.timer_elapsed ());

          capture = capture.chomp ();
          this._run_test_one_persona (capture);
        }
      catch (Error e)
        {
          error (e.message);
        }
    }

  /* test_preprepared_one_persona() x test_clones() */
  private void _test_clones_one_persona ()
    {
      this._add_500 ();
      this._add_500 ();
      this._test_preprepared_one_persona ();
    }

  public override void tear_down ()
    {
      try
        {
          Folks.TestUtils.run_test_helper_sync (
              { "eds/helper-delete-contacts",
                  "-u", ((!) this.eds_backend).address_book_uid });
        }
      catch (Error e)
        {
          error (e.message);
        }

      base.tear_down ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new PerfTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
