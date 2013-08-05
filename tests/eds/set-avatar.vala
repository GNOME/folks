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

public class SetAvatarTests : EdsTest.TestCase
{
  private IndividualAggregator _aggregator;
  private GLib.MainLoop _main_loop;
  private bool _found_before_update;
  private bool _found_after_update;
  private LoadableIcon _avatar;

  public SetAvatarTests ()
    {
      base ("SetAvatar");

      this.add_test ("setting avatar on e-d-s persona", this.test_set_avatar);
      this.add_test ("setting avatar on e-d-s individual",
          this.test_set_individual_avatar);
    }

  void test_set_avatar ()
    {
      Gee.HashMap<string, Value?> c1 = new Gee.HashMap<string, Value?> ();
      this._main_loop = new GLib.MainLoop (null, false);
      var avatar_path = Folks.TestUtils.get_source_test_data (
          "data/avatar-01.jpg");
      this._avatar = new FileIcon (File.new_for_path (avatar_path));
      Value? v;

      this._found_before_update = false;
      this._found_after_update = false;

      this.eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      c1.set ("full_name", (owned) v);
      this.eds_backend.add_contact (c1);

      this._test_set_avatar_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_before_update);
      assert (this._found_after_update);

      this._aggregator = null;
      this._main_loop = null;
    }

  private async void _test_set_avatar_async ()
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

      foreach (Individual i in added)
        {
          assert (i != null);

          var name = (Folks.NameDetails) i;

          if (name.full_name == "bernie h. innocenti")
            {
              i.notify["avatar"].connect (this._notify_avatar_cb);
              this._found_before_update = true;

              foreach (var p in i.personas)
                {
                  ((AvatarDetails) p).avatar = this._avatar;
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
      Folks.Individual i = (Folks.Individual) individual_obj;
      var name = (Folks.NameDetails) i;
      if (name.full_name == "bernie h. innocenti")
        {
          TestUtils.loadable_icons_content_equal.begin (i.avatar,
              this._avatar, -1,
              (obj, result) =>
            {
              if (TestUtils.loadable_icons_content_equal.end (result))
                {
                  this._found_after_update = true;

                  /* we can reach this point multiple times, so we need to make
                   * sure the main loop is still valid */
                  if (this._main_loop != null)
                    this._main_loop.quit ();
                }
            });
        }
    }

  void test_set_individual_avatar ()
    {
      var c1 = new Gee.HashMap<string, Value?> ();
      this._main_loop = new GLib.MainLoop (null, false);
      var avatar_path = Folks.TestUtils.get_source_test_data (
          "data/avatar-01.jpg");
      this._avatar = new FileIcon (File.new_for_path (avatar_path));
      Value? v;

      this._found_before_update = false;
      this._found_after_update = false;

      this.eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string ("John McClane");
      c1.set ("full_name", (owned) v);
      this.eds_backend.add_contact (c1);

      this._test_set_individual_avatar_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_before_update);
      assert (this._found_after_update);

      this._aggregator = null;
      this._main_loop = null;
    }

  private async void _test_set_individual_avatar_async ()
    {
      yield this.eds_backend.commit_contacts_to_addressbook ();

      var store = BackendStore.dup ();
      yield store.prepare ();

      this._aggregator = IndividualAggregator.dup ();
      this._aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          foreach (Individual i in added)
            {
              assert (i != null);

              var name = (Folks.NameDetails) i;

              if (name.full_name == "John McClane")
                {
                  i.notify["avatar"].connect (
                      this._notify_individual_avatar_cb);
                  this._found_before_update = true;

                  /* Just set the avatar on the individual */
                  i.change_avatar.begin (this._avatar, (obj, res) =>
                    {
                      try
                        {
                          i.change_avatar.end (res);

                          assert (this._found_before_update == true);
                          assert (this._found_after_update == true);

                          this._check_individual_has_avatar.begin (i,
                              (obj, res) =>
                            {
                              assert (
                                  this._check_individual_has_avatar.end (res)
                                      == true);

                              /* we can reach this point multiple times, so we
                               * need to make sure the main loop is still valid
                               */
                              if (this._main_loop != null)
                                this._main_loop.quit ();
                            });
                        }
                      catch (PropertyError e)
                        {
                          critical ("Unexpected error changing avatar: %s",
                              e.message);
                        }
                    });
                }
            }

          assert (removed.size == 1);

          foreach (var i in removed)
            {
              assert (i == null);
            }
        });

      try
        {
          yield this._aggregator.prepare ();
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }
    }

  private void _notify_individual_avatar_cb (Object individual_obj,
      ParamSpec ps)
    {
      /* Note: we can't check whether the avatar's correct here, as that's an
       * async operation, and if we start that operation in this signal
       * callback it'll probably end up finishing after the rest of the code in
       * _test_set_individual_avatar_async() has already failed. */
      this._found_after_update = true;
    }

  private async bool _check_individual_has_avatar (Individual i)
    {
      var name = (Folks.NameDetails) i;

      if (name.full_name == "John McClane")
        {
          var individual_equal = yield TestUtils.loadable_icons_content_equal (
              i.avatar, this._avatar, -1);

          if (individual_equal == true)
            {
              foreach (var p in i.personas)
                {
                  var persona_equal =
                      yield TestUtils.loadable_icons_content_equal (
                          (p as AvatarDetails).avatar, this._avatar, -1);

                  if (p.store.type_id == "eds" && persona_equal == true)
                    {
                      return true;
                    }
                }
            }
        }

      return false;
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new SetAvatarTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
