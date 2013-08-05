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

public class AdditionalNamesUpdatesTests : TrackerTest.TestCase
{
  private IndividualAggregator _aggregator;
  private bool _updated_additional_names_found;
  private string _updated_additional_names;
  private string _individual_id;
  private GLib.MainLoop _main_loop;
  private bool _initial_additional_names_found;
  private string _contact_urn;
  private string _initial_additional_names;
  private string _initial_fullname;

  public AdditionalNamesUpdatesTests ()
    {
      base ("AdditionalNamesUpdates");

      ((!) this.tracker_backend).debug = false;

      this.add_test ("additional names updates",
          this.test_additional_names_updates);
    }

  public void test_additional_names_updates ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._initial_fullname = "persona #1";
      this._initial_additional_names = "additional name #1";
      this._updated_additional_names = "updated additional name #1";
      this._contact_urn = "<urn:contact001>";

      c1.set (TrackerTest.Backend.URN, this._contact_urn);
      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._initial_fullname);
      c1.set (Trf.OntologyDefs.NCO_ADDITIONAL,
          this._initial_additional_names);
      ((!) this.tracker_backend).add_contact (c1);

      ((!) this.tracker_backend).set_up ();

      this._initial_additional_names_found = false;
      this._updated_additional_names_found = false;
      this._individual_id = "";

      var store = BackendStore.dup ();
      _test_additional_names_updates_async.begin (store);

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._initial_additional_names_found == true);
      assert (this._updated_additional_names_found == true);
    }

  private async void _test_additional_names_updates_async (BackendStore store)
    {
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

          if (this._initial_fullname == i.full_name)
            {
              var additional_names = i.structured_name.additional_names;
              if (additional_names == this._initial_additional_names)
                {
                  i.structured_name.notify["additional-names"].connect
                    (this._notify_additional_names_cb);
                  this._individual_id = i.id;
                  this._initial_additional_names_found = true;
                  ((!) this.tracker_backend).update_contact (this._contact_urn,
                      Trf.OntologyDefs.NCO_ADDITIONAL,
                      this._updated_additional_names);
                }
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  private void _notify_additional_names_cb (Object sname_obj, ParamSpec ps)
    {
      Folks.StructuredName sname = (Folks.StructuredName) sname_obj;
      var additional_names = sname.additional_names;

      if (additional_names == this._updated_additional_names)
        {
          this._updated_additional_names_found = true;
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new AdditionalNamesUpdatesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
