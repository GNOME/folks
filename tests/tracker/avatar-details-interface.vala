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

public class AvatarDetailsInterfaceTests : TrackerTest.TestCase
{
  private string _avatar_uri;
  private bool _avatars_are_equal;
  private GLib.MainLoop _main_loop;
  IndividualAggregator _aggregator;

  public AvatarDetailsInterfaceTests ()
    {
      base ("AvatarDetailsInterfaceTests");

      this.add_test ("test avatar details interface",
          this.test_avatar_details_interface);
    }

  public void test_avatar_details_interface ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      var avatar_path = Folks.TestUtils.get_source_test_data (
          "data/avatar-01.jpg");
      var temp_file = GLib.File.new_for_path (avatar_path);
      var full_avatar_path = temp_file.get_path ();
      this._avatar_uri = "file://" + full_avatar_path;
      this._avatars_are_equal = false;

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, "persona #1");
      c1.set (Trf.OntologyDefs.NCO_PHOTO, this._avatar_uri);
      ((!) this.tracker_backend).add_contact (c1);
      ((!) this.tracker_backend).set_up ();

      test_avatar_details_interface_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);
      assert (this._avatars_are_equal);
    }

  private async void test_avatar_details_interface_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();

      /* Set up the aggregator */
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

          string full_name = ((Folks.NameDetails) i).full_name;
          if (full_name != null)
            {
              i.notify["avatar"].connect (this._notify_avatar_cb);
              if (i.avatar != null)
                {
                  var src_avatar = File.new_for_uri (this._avatar_uri);
                  var src_icon = new FileIcon (src_avatar);
                  this._avatars_are_equal = src_icon.equal (i.avatar);
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

  private void _notify_avatar_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual individual = (Folks.Individual) individual_obj;
      var src_avatar = File.new_for_uri (this._avatar_uri);
      var src_icon = new FileIcon (src_avatar);
      this._avatars_are_equal = src_icon.equal (individual.avatar);
      this._main_loop.quit ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new AvatarDetailsInterfaceTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
