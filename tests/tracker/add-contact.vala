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

public class AddContactTests : Folks.TestCase
{
  private TrackerTest.Backend _tracker_backend;
  private bool _contact_added;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private GLib.MainLoop _main_loop;

  public AddContactTests ()
    {
      base ("AddContactTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test adding contacts ", this.test_add_contact);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_add_contact ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._persona_fullname = "persona #1";
      this._contact_added = false;

      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      this._tracker_backend.add_contact (c1);
      this._tracker_backend.set_up ();

      this._test_add_contact_async ();

      Timeout.add_seconds (5, () =>
          {
            this._main_loop.quit ();
            assert_not_reached ();
          });

      this._main_loop.run ();
      assert (this._contact_added == true);
      this._tracker_backend.tear_down ();
    }

  private async void _test_add_contact_async ()
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
      (Set<Individual> added,
       Set<Individual> removed,
       string? message,
       Persona? actor,
       GroupDetails.ChangeReason reason)
    {
      foreach (var i in added)
        {
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

        assert (removed.size == 0);
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

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new AddContactTests ().get_suite ());

  Test.run ();

  return 0;
}
