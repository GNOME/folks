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

public class AvatarDetailsInterfaceTests : Folks.TestCase
{
  private TrackerTest.Backend _tracker_backend;
  private string _avatar_uri;
  private bool _avatars_are_equal;
  private GLib.MainLoop _main_loop;
  IndividualAggregator _aggregator;

  public AvatarDetailsInterfaceTests ()
    {
      base ("AvatarDetailsInterfaceTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test avatar details interface",
          this.test_avatar_details_interface);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_avatar_details_interface ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      string avatar_path = Environment.get_variable ("AVATAR_FILE_PATH");
      var temp_file = GLib.File.new_for_path (avatar_path);
      var full_avatar_path = temp_file.get_path ();
      this._avatar_uri = "file://" + full_avatar_path;
      this._avatars_are_equal = false;

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, "persona #1");
      c1.set (Trf.OntologyDefs.NCO_PHOTO, this._avatar_uri);
      this._tracker_backend.add_contact (c1);
      this._tracker_backend.set_up ();

      test_avatar_details_interface_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();
      assert (this._avatars_are_equal);
      this._tracker_backend.tear_down ();
    }

  private async void test_avatar_details_interface_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();

      /* Set up the aggregator */
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
          string full_name = ((Folks.NameDetails) i).full_name;
          if (full_name != null)
            {
              i.notify["avatar"].connect (this._notify_avatar_cb);
              if (i.avatar != null)
                {
                  var src_avatar = File.new_for_uri (this._avatar_uri);
                  this._avatars_are_equal =
                      this._compare_files (src_avatar, i.avatar);
                  this._main_loop.quit ();
                }
            }
        }
    }

  private void _notify_avatar_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual individual = (Folks.Individual) individual_obj;
      var src_avatar = File.new_for_uri (this._avatar_uri);
      this._avatars_are_equal = this._compare_files (src_avatar,
          individual.avatar);
      this._main_loop.quit ();
    }

  private bool _compare_files (File a, File b)
    {
      uint8 *content_a;
      uint8 *content_b;

      try
        {
          a.load_contents (null, out content_a);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("couldn't load file a");
        }

      try
        {
          b.load_contents (null, out content_b);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("couldn't load file b");
        }

      return ((string) content_a) == ((string) content_b);
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new AvatarDetailsInterfaceTests ().get_suite ());

  Test.run ();

  return 0;
}