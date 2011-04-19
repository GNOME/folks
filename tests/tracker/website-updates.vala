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

public class WebsiteUpdatesTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private bool _updated_website_found;
  private bool _deleted_website_found;
  private bool _initial_website_found;
  private string _updated_website;
  private string _individual_id;
  private string _initial_fullname;
  private string _initial_website;
  private string _contact_urn;

  public WebsiteUpdatesTests ()
    {
      base ("WebsiteUpdates");

      this._tracker_backend = new TrackerTest.Backend ();
      this._tracker_backend.debug = false;

      this.add_test ("websites updates", this.test_website_updates);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_website_updates ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._initial_fullname = "persona #1";
      this._initial_website = "www.example1.org";
      this._updated_website = "www.example2.org";
      this._contact_urn = "<urn:contact001>";

      c1.set (TrackerTest.Backend.URN, this._contact_urn);
      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._initial_fullname);
      c1.set (TrackerTest.Backend.URLS, this._initial_website);
      this._tracker_backend.add_contact (c1);

      this._tracker_backend.set_up ();

      this._initial_website_found = false;
      this._updated_website_found = false;
      this._deleted_website_found = false;
      this._individual_id = "";

      this._test_website_updates_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._initial_website_found == true);
      assert (this._updated_website_found == true);

      this._tracker_backend.tear_down ();
    }

  private async void _test_website_updates_async ()
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
          if (i.full_name == this._initial_fullname)
            {
              i.notify["urls"].connect
                  (this._notify_website_cb);

              this._individual_id = i.id;

              foreach (var fd in i.urls)
                {
                  var website = fd.value;
                  if (website == this._initial_website)
                    {
                      this._initial_website_found = true;
                      string affl = "<affl:website>";
                      this._tracker_backend.insert_triplet (affl,
                          "a", Trf.OntologyDefs.NCO_AFFILIATION,
                          Trf.OntologyDefs.NCO_WEBSITE, this._updated_website);
                      this._tracker_backend.insert_triplet (this._contact_urn,
                          Trf.OntologyDefs.NCO_HAS_AFFILIATION,
                          affl);
                    }
                }
            }
        }

      assert (removed == null);
    }

  private void _notify_website_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;

      foreach (var fd in i.urls)
        {
          var website = fd.value;
          if (website == this._updated_website)
            {
              this._updated_website_found = true;
              this._main_loop.quit ();
            }
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new WebsiteUpdatesTests ().get_suite ());

  Test.run ();

  return 0;
}
