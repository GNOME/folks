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

public class SetRolesTests : EdsTest.TestCase
{
  private IndividualAggregator _aggregator;
  private GLib.MainLoop _main_loop;
  private bool _found_before_update;
  private bool _found_after_update;


  public SetRolesTests ()
    {
      base ("SetRoles");

      this.add_test ("setting roles on e-d-s persona",
          this.test_set_roles);
    }

  void test_set_roles ()
    {
      Gee.HashMap<string, Value?> c1 = new Gee.HashMap<string, Value?> ();
      this._main_loop = new GLib.MainLoop (null, false);
      Value? v;

      this._found_before_update = false;
      this._found_after_update = false;

      this.eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string ("The Guard");
      c1.set ("full_name", (owned) v);
      this.eds_backend.add_contact (c1);

      this._test_set_roles_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop, 5);

      assert (this._found_before_update);
      assert (this._found_after_update);
    }

  private async void _test_set_roles_async ()
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

      foreach (Individual i in added)
        {
          var name = (Folks.NameDetails) i;

          if (name.full_name == "The Guard")
            {
              i.notify["roles"].connect (this._notify_roles_cb);
              this._found_before_update = true;

              foreach (var p in i.personas)
                {
                  var role_fds = new HashSet<RoleFieldDetails> (
                      AbstractFieldDetails<Role>.hash_static,
                      AbstractFieldDetails<Role>.equal_static);
                  var r1 = new Role ("Dr.", "The Nut House Ltd");
                  r1.role = "The Manager";
                  var role_fd1 = new RoleFieldDetails (r1);
                  role_fds.add (role_fd1);
                  ((RoleDetails) p).roles = role_fds;
                }
            }
        }
    }

  private void _notify_roles_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      foreach (var role_fd in i.roles)
        {
          var r1 = new Role ("Dr.", "The Nut House Ltd");
          r1.role = "The Manager";
          var role_fd_expected = new RoleFieldDetails (r1);
          if (role_fd.equal (role_fd_expected))
            {
              this._found_after_update = true;
              this._main_loop.quit ();
            }
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new SetRolesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
