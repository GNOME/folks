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

public class FavouriteUpdatesTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private bool _is_favourite_1;
  private string _individual_id_1;
  private bool _is_favourite_2;
  private string _individual_id_2;
  private string _initial_fullname_1;
  private string _contact_urn_1;
  private string _initial_fullname_2;
  private string _contact_urn_2;

  public FavouriteUpdatesTests ()
    {
      base ("FavouriteUpdates");

      ((!) this.tracker_backend).debug = false;

      this.add_test ("favourite update", this.test_favourite_update);
    }

  public void test_favourite_update ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      Gee.HashMap<string, string> c2 = new Gee.HashMap<string, string> ();
      this._initial_fullname_1 = "persona #1";
      this._contact_urn_1 = "<urn:contact001>";
      this._initial_fullname_2 = "persona #2";
      this._contact_urn_2 = "<urn:contact002>";

      c1.set (TrackerTest.Backend.URN, this._contact_urn_1);
      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._initial_fullname_1);
      ((!) this.tracker_backend).add_contact (c1);

      c2.set (TrackerTest.Backend.URN, this._contact_urn_2);
      c2.set (Trf.OntologyDefs.NCO_FULLNAME, this._initial_fullname_2);
      c2.set (Trf.OntologyDefs.NAO_TAG, "");
      ((!) this.tracker_backend).add_contact (c2);

      ((!) this.tracker_backend).set_up ();

      this._is_favourite_1 = false;
      this._individual_id_1 = "";
      this._is_favourite_2 = true;
      this._individual_id_2 = "";

      this._test_favourite_update_async.begin ();

      // this timer is slightly higher than usual because sleep
      // to ensure a (usually delayed) INSERT event has happened
      TestUtils.loop_run_with_timeout (this._main_loop, 7);

      assert (this._is_favourite_1 == true);
      assert (this._is_favourite_2 == false);
    }

  private async void _test_favourite_update_async ()
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

          if (i.full_name == this._initial_fullname_1)
            {
              i.notify["is-favourite"].connect
                  (this._notify_favourite_cb);
              this._individual_id_1 = i.id;
              ((!) this.tracker_backend).update_favourite (this._contact_urn_1,
                  true);
            }
          else if (i.full_name == this._initial_fullname_2)
            {
              i.notify["is-favourite"].connect
                  (this._notify_favourite_cb);
              this._individual_id_2 = i.id;
              // HACK: we need to make sure the INSERT event was delivered
              Timeout.add_seconds (1, () =>
                  {
                    ((!) this.tracker_backend).update_favourite
                        (this._contact_urn_2, false);
                    return false;
                  });
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  private void _notify_favourite_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      if (i.id == this._individual_id_1)
        {
          this._is_favourite_1 = i.is_favourite;
        }
      else if (i.id == this._individual_id_2)
        {
          this._is_favourite_2 = i.is_favourite;
        }

      if (this._is_favourite_1 == true &&
          this._is_favourite_2 == false)
        this._main_loop.quit ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new FavouriteUpdatesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
