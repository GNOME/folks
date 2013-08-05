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

using EdsTest;
using Folks;
using Gee;

public class AvatarDetailsTests : EdsTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private Gee.HashMap<string, Value?> _c1;
  private bool _avatars_are_equal;
  private string _avatar_path;

  public AvatarDetailsTests ()
    {
      base ("AvatarDetails");

      this.add_test ("avatar details interface", this.test_avatar);
    }

  public void test_avatar ()
    {
      this._c1 = new Gee.HashMap<string, Value?> ();
      this._main_loop = new GLib.MainLoop (null, false);
      this._avatar_path = Folks.TestUtils.get_source_test_data (
          "data/avatar-01.jpg");
      this._avatars_are_equal = false;
      Value? v;

      this.eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      this._c1.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string (this._avatar_path);
      this._c1.set ("avatar",(owned) v);
      this.eds_backend.add_contact (this._c1);

      this._test_avatar_async.begin ();

      TestUtils.loop_run_with_non_fatal_timeout (this._main_loop);

      assert (this._avatars_are_equal);
   }

  private async void _test_avatar_async ()
    {

      yield this.eds_backend.commit_contacts_to_addressbook ();

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

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }

      foreach (Individual i in added)
        {
          assert (i != null);

          assert (i.personas.size == 1);

          if (i.full_name == "bernie h. innocenti")
            {
              i.notify["avatar"].connect (this._notify_cb);
              this._check_avatar.begin (i.avatar);
            }
        }
   }

  private void _notify_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      this._check_avatar.begin (i.avatar);
    }

  private async void _check_avatar (LoadableIcon? avatar)
    {
      if (avatar != null)
        {
          var b = new FileIcon (File.new_for_path (this._avatar_path));

          this._avatars_are_equal =
            yield TestUtils.loadable_icons_content_equal (
                avatar, b, -1);
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new AvatarDetailsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
