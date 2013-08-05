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

public class GenderDetailsInterfaceTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private bool _found_gender;
  private string _gender;
  private string _fullname;

  public GenderDetailsInterfaceTests ()
    {
      base ("GenderDetailsInterfaceTests");

      ((!) this.tracker_backend).debug = false;

      this.add_test ("test gender details interface",
          this.test_gender_details_interface);
    }

  public void test_gender_details_interface ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._fullname = "persona #1";
      this._gender = Trf.OntologyDefs.NCO_MALE;

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._fullname);
      c1.set (Trf.OntologyDefs.NCO_GENDER, this._gender);
      ((!) this.tracker_backend).add_contact (c1);
      ((!) this.tracker_backend).set_up ();

      this._found_gender = false;

      this._test_gender_details_interface_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_gender == true);
    }

  private async void _test_gender_details_interface_async ()
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

          if (i.full_name == this._fullname)
            {
              i.notify["gender"].connect (this._notify_gender_cb);
              if (i.gender == Gender.MALE)
                {
                  this._found_gender = true;
                  this._main_loop.quit ();
                }
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  void _notify_gender_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual individual = (Folks.Individual) individual_obj;
      if (individual.gender == Gender.MALE)
        {
          this._found_gender = true;
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new GenderDetailsInterfaceTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
