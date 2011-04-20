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

public class AvatarUpdatesTests : Folks.TestCase
{
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private bool _updated_avatar_found;
  private string _updated_avatar;
  private string _individual_id;
  private GLib.MainLoop _main_loop;
  private bool _initial_avatar_found;
  private string _initial_fullname;
  private string _initial_avatar;
  private string _contact_urn;
  private string _photo_urn;

  public AvatarUpdatesTests ()
    {
      base ("AvatarUpdates");

      this._tracker_backend = new TrackerTest.Backend ();
      this._tracker_backend.debug = false;

      this.add_test ("avatar updates", this.test_avatar_updates);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_avatar_updates ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._initial_fullname = "persona #1";
      this._initial_avatar = "file:///tmp/avatar-01";
      this._contact_urn = "<urn:contact001>";
      this._photo_urn = "<" + this._initial_avatar + ">";
      this._updated_avatar = "file:///tmp/avatar-02";

      c1.set (TrackerTest.Backend.URN, this._contact_urn);
      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._initial_fullname);
      c1.set (Trf.OntologyDefs.NCO_PHOTO, this._initial_avatar);
      this._tracker_backend.add_contact (c1);

      this._tracker_backend.set_up ();

      this._initial_avatar_found = false;
      this._updated_avatar_found = false;
      this._individual_id = "";

      test_avatar_updates_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._initial_avatar_found == true);
      assert (this._updated_avatar_found == true);

      this._tracker_backend.tear_down ();
    }

  private async void test_avatar_updates_async ()
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
          if (i.full_name == this._initial_fullname)
            {
              i.notify["avatar"].connect (this._notify_avatar_cb);
              this._individual_id = i.id;

              if (i.avatar != null &&
                  i.avatar.get_uri () == this._initial_avatar)
                {
                  this._initial_avatar_found = true;

                  this._tracker_backend.remove_triplet (this._contact_urn,
                      Trf.OntologyDefs.NCO_PHOTO, this._photo_urn);

                  string photo_urn_2 = "<" + this._updated_avatar;
                  photo_urn_2 += ">";
                  this._tracker_backend.insert_triplet (photo_urn_2,
                      "a", "nfo:Image, nie:DataObject",
                      Trf.OntologyDefs.NIE_URL,
                      this._updated_avatar);

                  this._tracker_backend.insert_triplet
                      (this._contact_urn,
                      Trf.OntologyDefs.NCO_PHOTO, photo_urn_2);

                }
            }

          assert (removed.size == 0);
        }
    }

  private void _notify_avatar_cb ()
    {
      var i = this._aggregator.individuals.get (this._individual_id);
      if (i == null)
        return;

      if (i.avatar != null &&
          i.avatar.get_uri () == this._updated_avatar)
        {
          this._main_loop.quit ();
          this._updated_avatar_found = true;
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new AvatarUpdatesTests ().get_suite ());

  Test.run ();

  return 0;
}
