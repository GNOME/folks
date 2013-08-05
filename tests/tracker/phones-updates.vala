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

public class PhonesUpdatesTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _initial_fullname_1;
  private string _contact_urn_1;
  private string _phone_1;
  private string _phone_2;
  private string _individual_id;
  private bool _initial_phone_found;
  private bool _initial_phone_found_again;
  private bool _updated_phone_found;

  public PhonesUpdatesTests ()
    {
      base ("PhonesUpdates");

      ((!) this.tracker_backend).debug = false;

      this.add_test ("phones updates", this.test_phones_updates);
    }

  public void test_phones_updates ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._initial_fullname_1 = "persona #1";
      this._contact_urn_1 = "<urn:contact001>";
      this._phone_1 = "12345";
      this._phone_2 = "54321";

      c1.set (TrackerTest.Backend.URN, this._contact_urn_1);
      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._initial_fullname_1);
      c1.set (Trf.OntologyDefs.NCO_PHONE_PROP, this._phone_1);
      ((!) this.tracker_backend).add_contact (c1);

      ((!) this.tracker_backend).set_up ();

      this._individual_id = "";
      this._initial_phone_found = false;
      this._initial_phone_found_again = false;
      this._updated_phone_found = false;

      this._test_phones_updates_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._initial_phone_found == true);
      assert (this._initial_phone_found_again == false);
      assert (this._updated_phone_found == true);
    }

  private async void _test_phones_updates_async ()
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
              this._individual_id = i.id;

              i.notify["phone-numbers"].connect (this._notify_phones_cb);

              foreach (var fd in i.phone_numbers)
                {
                  var phone = fd.value;
                  if (phone == this._phone_1)
                    {
                      this._initial_phone_found = true;
                      this._update_phone ();
                    }
                }
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  private void _notify_phones_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      foreach (var fd in i.phone_numbers)
        {
          var phone = fd.value;
          if (phone == this._phone_1)
            {
              this._initial_phone_found_again = true;
            }
          if (phone == this._phone_2)
            {
              this._updated_phone_found = true;
              this._main_loop.quit ();
            }
        }
    }

  private void _update_phone ()
    {
      var urn_phone_1 = "<" + this._phone_1 + ">";
      ((!) this.tracker_backend).remove_triplet (this._contact_urn_1,
          Trf.OntologyDefs.NCO_HAS_AFFILIATION, urn_phone_1);

      var urn_phone_2 = "<phone:" + this._phone_2 + ">";
      ((!) this.tracker_backend).insert_triplet (urn_phone_2,
          "a", Trf.OntologyDefs.NCO_PHONE,
          Trf.OntologyDefs.NCO_PHONE_PROP,
          this._phone_2);

      var affl_2 = "<" + this._phone_2 + ">";
      ((!) this.tracker_backend).insert_triplet
          (affl_2,
          "a", Trf.OntologyDefs.NCO_AFFILIATION);
      ((!) this.tracker_backend).insert_triplet
          (affl_2,
          Trf.OntologyDefs.NCO_HAS_PHONE, urn_phone_2);

      ((!) this.tracker_backend).insert_triplet
          (this._contact_urn_1,
          Trf.OntologyDefs.NCO_HAS_AFFILIATION, affl_2);
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new PhonesUpdatesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
