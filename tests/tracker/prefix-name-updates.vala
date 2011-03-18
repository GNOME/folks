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

public class PrefixNameUpdatesTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private bool _updated_prefix_name_found;
  private bool _initial_prefix_name_found;
  private string _updated_prefix_name;
  private string _individual_id;
  private string _initial_fullname;
  private string _initial_prefix_name;
  private string _contact_urn;

  public PrefixNameUpdatesTests ()
    {
      base ("PrefixNameUpdates");

      this._tracker_backend = new TrackerTest.Backend ();
      this._tracker_backend.debug = false;

      this.add_test ("prefix name updates", this.test_prefix_name_updates);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_prefix_name_updates ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._initial_fullname = "persona #1";
      this._initial_prefix_name = "prefix name #1";
      this._updated_prefix_name = "updated prefix #1";
      this._contact_urn = "<urn:contact001>";

      c1.set (TrackerTest.Backend.URN, this._contact_urn);
      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._initial_fullname);
      c1.set (Trf.OntologyDefs.NCO_PREFIX, this._initial_prefix_name);
      this._tracker_backend.add_contact (c1);

      this._tracker_backend.set_up ();

      this._initial_prefix_name_found = false;
      this._updated_prefix_name_found = false;
      this._individual_id = "";

      this._test_prefix_name_updates_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._initial_prefix_name_found == true);
      assert (this._updated_prefix_name_found == true);

      this._tracker_backend.tear_down ();
    }

  private async void _test_prefix_name_updates_async ()
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
          if (this._initial_fullname == i.full_name)
            {
              var prefix_name = i.structured_name.prefixes;
              if (prefix_name == this._initial_prefix_name)
                {
                  i.structured_name.notify["prefixes"].connect
                  (this._notify_prefix_name_cb);
                  this._individual_id = i.id;
                  this._initial_prefix_name_found = true;
                  this._tracker_backend.update_contact (this._contact_urn,
                      Trf.OntologyDefs.NCO_PREFIX, this._updated_prefix_name);
                }
            }
        }
      assert (removed == null);
    }

  private void _notify_prefix_name_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.StructuredName sname = (Folks.StructuredName) individual_obj;
      var prefix_name = sname.prefixes;
      if (prefix_name == this._updated_prefix_name)
        {
          this._updated_prefix_name_found = true;
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new PrefixNameUpdatesTests ().get_suite ());

  Test.run ();

  return 0;
}
