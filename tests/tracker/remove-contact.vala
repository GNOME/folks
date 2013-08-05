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

public class RemoveContactTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private bool _contact_added;
  private bool _contact_removed;
  private string _individual_id;
  private string _persona_fullname;

  public RemoveContactTests ()
    {
      base ("RemoveContactTests");

      this.add_test ("test removing contacts ", this.test_remove_contact);
    }

  public void test_remove_contact ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._persona_fullname = "persona #1";
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      ((!) this.tracker_backend).add_contact (c1);
      ((!) this.tracker_backend).set_up ();

      this._contact_added = false;
      this._contact_removed = false;
      this._individual_id = "";

      this._test_remove_contact_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._contact_added == true);
      assert (this._contact_removed == true);
    }

  private async void _test_remove_contact_async ()
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
          if (i == null)
            {
              continue;
            }

          string full_name = i.full_name;
          if (full_name == this._persona_fullname)
            {
              this._contact_added = true;
              this._individual_id = i.id;
              foreach (var persona in i.personas)
                {
                  var contact_id = persona.iid.split (":")[1];
                  ((!) this.tracker_backend).remove_contact (contact_id);
                }
            }
        }

      foreach (var i in removed)
        {
          if (i == null)
            {
              continue;
            }

          if (i.id == this._individual_id)
            {
              this._contact_removed = true;
              this._main_loop.quit ();
            }
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new RemoveContactTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
