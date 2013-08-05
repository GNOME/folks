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

public class AddContactTests : TrackerTest.TestCase
{
  private bool _contact_added;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private GLib.MainLoop _main_loop;

  public AddContactTests ()
    {
      base ("AddContactTests");

      this.add_test ("test adding contacts ", this.test_add_contact);
    }

  public void test_add_contact ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._persona_fullname = "persona #1";
      this._contact_added = false;

      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      var tracker_backend = (!) this.tracker_backend;
      tracker_backend.add_contact (c1);
      tracker_backend.set_up ();

      this._test_add_contact_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);
      assert (this._contact_added == true);
    }

  private async void _test_add_contact_async ()
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
          i.notify["full-name"].connect (this._notify_full_name_cb);
          if (full_name != null)
            {
              if (full_name == this._persona_fullname)
                {
                  this._contact_added = true;
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

  private void _notify_full_name_cb ()
    {
      var individuals = this._aggregator.individuals.values;
      foreach (var i in individuals)
        {
          if (i.full_name == this._persona_fullname)
            {
              this._contact_added = true;
              this._main_loop.quit ();
            }
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new AddContactTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
