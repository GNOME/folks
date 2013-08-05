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

public class SetRolesTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private bool _role_found;
  private RoleFieldDetails _role_fd;

  public SetRolesTests ()
    {
      base ("SetRolesTests");

      this.add_test ("test setting roles ",
          this.test_set_roles);
    }

  public void test_set_roles ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._persona_fullname = "persona #1";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      ((!) this.tracker_backend).add_contact (c1);

      var role = new Role ("some title", "some organisation");
      role.role = "some role";
      this._role_fd = new RoleFieldDetails (role);

      ((!) this.tracker_backend).set_up ();

      this._role_found = false;

      this._test_set_roles_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._role_found);
    }

  private async void _test_set_roles_async ()
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

          if (i.full_name == this._persona_fullname)
            {
              i.notify["roles"].connect (this._notify_roles_cb);

              Gee.HashSet<RoleFieldDetails> role_fds =
                new HashSet<RoleFieldDetails> (
                    AbstractFieldDetails<Role>.hash_static,
                    AbstractFieldDetails<Role>.equal_static);
              var role = new Role ("some title", "some organisation");
              role.role = "some role";
              var role_fd = new RoleFieldDetails (role);
              role_fds.add ((owned) role_fd);

              foreach (var p in i.personas)
                {
                  ((RoleDetails) p).roles = role_fds;
                }
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  private void _notify_roles_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      if (i.full_name == this._persona_fullname)
        {
          foreach (var role_fd in i.roles)
            {
              if (role_fd.equal (this._role_fd))
                {
                  this._role_found = true;
                  this._main_loop.quit ();
                }
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
