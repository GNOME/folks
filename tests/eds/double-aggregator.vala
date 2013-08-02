/*
 * Copyright (C) 2013 Intel Corporation
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
 *
 */

using EdsTest;
using Folks;
using Gee;

public class DoubleAggregatorTests : EdsTest.TestCase
{
  private IndividualAggregator _aggregator;
  private IndividualAggregator _aggregator2;
  private GLib.MainLoop _main_loop;
  private int _test_num = -1;

  public DoubleAggregatorTests ()
    {
      base ("DoubleAggregator");

      this.add_test ("unlink double aggregator", this.test_unlink);
      this.add_test ("remove double aggregator", this.test_remove);
    }

  public override void set_up ()
    {
      base.set_up ();

      this._main_loop = new GLib.MainLoop (null, false);
      this._aggregator = new IndividualAggregator ();
    }

  public override void create_backend ()
    {
      /* Create a new backend (by name) each set up to guarantee we don't
       * inherit state from the last test.
       * FIXME: bgo#690830 */
      this._test_num++;
      this.eds_backend = new EdsTest.Backend ();
      this.eds_backend.set_up (false, @"test$_test_num");
    }

  public override void tear_down ()
    {
      this._aggregator = null;
      this._aggregator2 = null;
      this._main_loop = null;

      base.tear_down ();
    }

  void test_unlink ()
    {
      this._prepare_test ();

      this._unlink_individuals.begin ((o, r) =>
        {
          this._unlink_individuals.end (r);
        });
      TestUtils.loop_run_with_timeout (this._main_loop);
    }

  void test_remove ()
    {
      this._prepare_test ();

      this._remove_individual.begin ((o, r) =>
        {
          this._remove_individual.end (r);
        });
      TestUtils.loop_run_with_timeout (this._main_loop);
    }

  void _prepare_test ()
    {
      // ADD 2 EDS contacts
      Gee.HashMap<string, Value?> c1 = new Gee.HashMap<string, Value?> ();
      var v = Value (typeof (string));
      v.set_string ("Badger");
      c1.set ("full_name", (owned) v);
      this.eds_backend.add_contact (c1);

      Gee.HashMap<string, Value?> c2 = new Gee.HashMap<string, Value?> ();
      v = Value (typeof (string));
      v.set_string ("Mushroom");
      c2.set ("full_name", (owned) v);
      this.eds_backend.add_contact (c2);

      this._do_test_async.begin ();
      TestUtils.loop_run_with_timeout (this._main_loop);
    }

  private async void _prepare_aggregator (IndividualAggregator aggregator)
    {
      try
         {
           yield aggregator.prepare ();
         }
       catch (GLib.Error e)
         {
           GLib.error ("Error when calling prepare: %s\n", e.message);
         }
    }

  private async void _do_test_async ()
    {
      yield this.eds_backend.commit_contacts_to_addressbook ();

      this._aggregator.notify["is-quiescent"].connect (this._link_individuals);
      yield this._prepare_aggregator (this._aggregator);
    }

  private async void _link_individuals ()
    {
      /* Link both individuals */
      assert (this._aggregator.individuals.size == 2);

      var personas = new HashSet<Persona> ();

      foreach (var individual in this._aggregator.individuals.values)
        foreach (var persona in individual.personas)
          personas.add (persona);

      try
        {
          yield this._aggregator.link_personas (personas);
        }
      catch (GLib.Error e)
        {
          GLib.error ("link_personas: %s\n", e.message);
        }

      /* Individuals have been linked together */
      assert (this._aggregator.individuals.size == 1);

      this._aggregator2 = new IndividualAggregator ();
      this._aggregator2.notify["is-quiescent"].connect (this._aggregator2_is_quiescent);
      yield this._prepare_aggregator (this._aggregator2);
    }

  private void _aggregator2_is_quiescent ()
    {
      this._main_loop.quit ();
    }

  private async void _unlink_individuals ()
    {
      assert (this._aggregator.individuals.size == 1);

      var individuals = this._aggregator.individuals.values.to_array ();

      try
        {
          yield this._aggregator.unlink_individual (individuals[0]);
        }
      catch (GLib.Error e)
        {
          GLib.error ("unlink_individual: %s\n", e.message);
        }

      this._main_loop.quit ();
    }

  private async void _remove_individual ()
    {
      assert (this._aggregator.individuals.size == 1);

      var individuals = this._aggregator.individuals.values.to_array ();

      try
        {
          yield this._aggregator.remove_individual (individuals[0]);
        }
      catch (GLib.Error e)
        {
          GLib.error ("remove_individual: %s\n", e.message);
        }

      this._main_loop.quit ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new DoubleAggregatorTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
