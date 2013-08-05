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

public class FavouriteDetailsInterfaceTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private string _fullname_p1;
  private string _fullname_p2;
  private string _fullname_p3;
  private bool _found_p1;
  private bool _found_p2;
  private bool _found_p3;
  private IndividualAggregator _aggregator;

  public FavouriteDetailsInterfaceTests ()
    {
      base ("FavouriteDetailsInterfaceTests");

      this.add_test ("test favourite details interface",
          this.test_favourite_details_interface);
    }

  public void test_favourite_details_interface ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      Gee.HashMap<string, string> c2 = new Gee.HashMap<string, string> ();
      Gee.HashMap<string, string> c3 = new Gee.HashMap<string, string> ();
      this._fullname_p1 = "favourite persona #1";
      this._fullname_p2 = "favourite persona #2";
      this._fullname_p3 = "favourite persona #3";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._fullname_p1);
      c1.set (Trf.OntologyDefs.NAO_TAG, "");
      ((!) this.tracker_backend).add_contact (c1);

      c2.set (Trf.OntologyDefs.NCO_FULLNAME, this._fullname_p2);
      c2.set (Trf.OntologyDefs.NAO_TAG, "");
      ((!) this.tracker_backend).add_contact (c2);

      c3.set (Trf.OntologyDefs.NCO_FULLNAME, this._fullname_p3);
      ((!) this.tracker_backend).add_contact (c3);

      ((!) this.tracker_backend).set_up ();

      this._found_p1 = false;
      this._found_p2 = false;
      this._found_p3 = false;

      this._test_favourite_details_interface_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_p1 == true);
      assert (this._found_p2 == true);
      assert (this._found_p3 == true);
    }

  private async void _test_favourite_details_interface_async ()
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

          string full_name = i.full_name;
          if (full_name != null)
            {
              if (full_name == this._fullname_p1)
                {
                  assert (i.is_favourite == true);
                  this._found_p1 = true;
                }
              else if (full_name == this._fullname_p2)
                {
                  assert (i.is_favourite == true);
                  this._found_p2 = true;
                }
              else if (full_name == this._fullname_p3)
                {
                  assert (i.is_favourite == false);
                  this._found_p3 = true;
                }
            }
        }

        if (this._found_p1 &&
            this._found_p2 &&
            this._found_p3)
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

  var tests = new FavouriteDetailsInterfaceTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
