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

public class RoleDetailsInterfaceTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private bool _found_role;
  private string _fullname;
  private string _affiliaton;

  public RoleDetailsInterfaceTests ()
    {
      base ("RoleDetailsInterfaceTests");

      ((!) this.tracker_backend).debug = false;

      this.add_test ("test role details interface",
          this.test_role_details_interface);
    }

  public void test_role_details_interface ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._fullname = "persona #1";
      this._affiliaton = "boss,Company,Role";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._fullname);
      c1.set (Trf.OntologyDefs.NCO_HAS_AFFILIATION, this._affiliaton);
      ((!) this.tracker_backend).add_contact (c1);

      ((!) this.tracker_backend).set_up ();

      this._found_role = false;

      this._test_role_details_interface_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_role == true);
    }

  private async void _test_role_details_interface_async ()
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

          if (i.full_name == this._fullname)
            {
              foreach (var role_fd in i.roles)
                {
                  var role_expected = new Role ("boss", "Company");
                  role_expected.role = "Role";
                  var role_fd_expected = new RoleFieldDetails (role_expected);

                  /* We copy the tracker_id - we don't know it.
                   * We could get it from the 1st personas iid but there is no
                   * real need. */
                  role_fd_expected.id = role_fd.id;

                  if (role_fd.equal (role_fd_expected))
                    {
                      /* Ensure that setting the Role uid directly (which is
                       * deprecated) is equivalent to setting the id on a
                       * RoleFieldDetails directly */
                      var role_2 = new Role (
                          role_expected.title,
                          role_expected.organisation_name,
                          role_fd.id);
                      role_2.role = role_expected.role;
                      var role_fd_2 = new RoleFieldDetails (role_2);
                      assert (role_fd.equal (role_fd_2));
                      assert (role_fd.id == role_fd_2.id);

                      this._found_role = true;
                      this._main_loop.quit ();
                    }
                }
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new RoleDetailsInterfaceTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
