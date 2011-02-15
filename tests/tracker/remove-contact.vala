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

public class RemoveContactTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private bool _contact_added;
  private bool _contact_removed;
  private string _individual_id;
  private string _persona_fullname;

  public RemoveContactTests ()
    {
      base ("RemoveContactTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test removing contacts ", this.test_remove_contact);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_remove_contact ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._persona_fullname = "persona #1";
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      this._tracker_backend.add_contact (c1);
      this._tracker_backend.set_up ();

      this._contact_added = false;
      this._contact_removed = false;
      this._individual_id = "";

      this._test_remove_contact_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._contact_added == true);
      assert (this._contact_removed == true);

      this._tracker_backend.tear_down ();
    }

  private async void _test_remove_contact_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = new IndividualAggregator ();
      this._aggregator.individuals_changed.connect
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

  private void _individuals_changed_cb
      (GLib.List<Individual>? added,
       GLib.List<Individual>? removed,
       string? message,
       Persona? actor,
       GroupDetails.ChangeReason reason)
    {
      foreach (unowned Individual i in added)
        {
          string full_name = i.full_name;
          if (full_name == this._persona_fullname)
            {
              this._contact_added = true;
              this._individual_id = i.id;
              var contact_id = i.personas.nth_data (0).iid.split (":")[1];
              this._tracker_backend.remove_contact (contact_id);
            }
        }

      foreach (unowned Individual i in added)
        {
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

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new RemoveContactTests ().get_suite ());

  Test.run ();

  return 0;
}
