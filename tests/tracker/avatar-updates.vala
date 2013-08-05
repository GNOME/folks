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

public class AvatarUpdatesTests : TrackerTest.TestCase
{
  private IndividualAggregator _aggregator;
  private bool _updated_avatar_found;
  private string _updated_avatar_uri;
  private LoadableIcon _updated_avatar;
  private string _individual_id;
  private GLib.MainLoop _main_loop;
  private bool _initial_avatar_found;
  private string _initial_fullname;
  private string _initial_avatar_uri;
  private string _contact_urn;
  private string _photo_urn;

  public AvatarUpdatesTests ()
    {
      base ("AvatarUpdates");

      ((!) this.tracker_backend).debug = false;

      this.add_test ("avatar updates", this.test_avatar_updates);
    }

  public void test_avatar_updates ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._initial_fullname = "persona #1";
      this._initial_avatar_uri = "file:///tmp/avatar-01";
      this._contact_urn = "<urn:contact001>";
      this._photo_urn = "<" + this._initial_avatar_uri + ">";
      this._updated_avatar_uri = "file:///tmp/avatar-02";
      this._updated_avatar =
          new FileIcon (File.new_for_uri (this._updated_avatar_uri));

      c1.set (TrackerTest.Backend.URN, this._contact_urn);
      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._initial_fullname);
      c1.set (Trf.OntologyDefs.NCO_PHOTO, this._initial_avatar_uri);
      ((!) this.tracker_backend).add_contact (c1);

      ((!) this.tracker_backend).set_up ();

      this._initial_avatar_found = false;
      this._updated_avatar_found = false;
      this._individual_id = "";

      test_avatar_updates_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._initial_avatar_found == true);
      assert (this._updated_avatar_found == true);
    }

  private async void test_avatar_updates_async ()
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

          if (i.full_name == this._initial_fullname)
            {
              i.notify["avatar"].connect (this._notify_avatar_cb);
              this._individual_id = i.id;

              var initial_avatar =
                  new FileIcon (File.new_for_uri (this._initial_avatar_uri));

              if (i.avatar != null && i.avatar.equal (initial_avatar) == true)
                {
                  this._initial_avatar_found = true;

                  ((!) this.tracker_backend).remove_triplet (this._contact_urn,
                      Trf.OntologyDefs.NCO_PHOTO, this._photo_urn);

                  string photo_urn_2 = "<" + this._updated_avatar_uri;
                  photo_urn_2 += ">";
                  ((!) this.tracker_backend).insert_triplet (photo_urn_2,
                      "a", "nfo:Image, nie:DataObject",
                      Trf.OntologyDefs.NIE_URL,
                      this._updated_avatar_uri);

                  ((!) this.tracker_backend).insert_triplet
                      (this._contact_urn,
                      Trf.OntologyDefs.NCO_PHOTO, photo_urn_2);

                }
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  private void _notify_avatar_cb ()
    {
      var i = this._aggregator.individuals.get (this._individual_id);
      if (i == null)
        return;

      if (i.avatar != null &&
          i.avatar.equal (this._updated_avatar))
        {
          this._main_loop.quit ();
          this._updated_avatar_found = true;
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new AvatarUpdatesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
