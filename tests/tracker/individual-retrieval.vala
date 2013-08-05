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
 * Authors: Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *
 */

using Tracker.Sparql;
using TrackerTest;
using Folks;
using Gee;

public class IndividualRetrievalTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private Gee.HashMap<string, string> _c1;
  private Gee.HashMap<string, string> _c2;

  public IndividualRetrievalTests ()
    {
      base ("IndividualRetrieval");

      this.add_test ("singleton individuals", this.test_singleton_individuals);
    }

  public void test_singleton_individuals ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._c1 = new Gee.HashMap<string, string> ();
      this._c2 = new Gee.HashMap<string, string> ();

      this._c1.set (Trf.OntologyDefs.NCO_FULLNAME, "persona #1");
      ((!) this.tracker_backend).add_contact (this._c1);
      this._c2.set (Trf.OntologyDefs.NCO_FULLNAME, "persona #2");
      ((!) this.tracker_backend).add_contact (this._c2);
      ((!) this.tracker_backend).set_up ();

      this._test_singleton_individuals_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._c1.size == 0);
      assert (this._c2.size == 0);
    }

  private async void _test_singleton_individuals_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = IndividualAggregator.dup ();
      this._aggregator.individuals_changed_detailed.connect
          (this._individuals_changed_cb);
      try
        {
          yield this._aggregator.prepare ();
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }
    }

  private void _individuals_changed_cb (
       MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();
      var removed = changes.get_keys ();

      foreach (var i in added)
        {
          assert (i != null);

          string full_name = ((Folks.NameDetails) i).full_name;
          if (full_name != null)
            {
              if (this._c1.get (Trf.OntologyDefs.NCO_FULLNAME) == full_name)
                {
                  this._c1.unset (Trf.OntologyDefs.NCO_FULLNAME);
                }

              if (this._c2.get (Trf.OntologyDefs.NCO_FULLNAME) == full_name)
                {
                  this._c2.unset (Trf.OntologyDefs.NCO_FULLNAME);
                }
            }
        }

        if (this._c1.size == 0 &&
            this._c2.size == 0)
          this._main_loop.quit ();

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
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
