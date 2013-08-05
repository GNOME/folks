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

public class DefaultContactTests : TrackerTest.TestCase
{
  private bool _found_default_user;
  private bool _found_not_user;
  private bool _found_unknown_user;
  private GLib.MainLoop _main_loop;
  private string _fullname_persona;
  private IndividualAggregator _aggregator;
  public DefaultContactTests ()
    {
      base ("DefaultContactTests");

      this.add_test ("test default contact", this.test_default_contact);
    }

  public void test_default_contact ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._fullname_persona = "persona #1";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._fullname_persona);
      ((!) this.tracker_backend).add_contact (c1);

      ((!) this.tracker_backend).set_up ();

      this._found_default_user = false;
      this._found_not_user = false;
      this._found_unknown_user = false;

      _test_default_contact_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_default_user == true);
      assert (this._found_not_user == true);
      assert (this._found_unknown_user == false);
    }

  private async void _test_default_contact_async ()
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

          string full_name = i.full_name;
          if (full_name != null && full_name == this._fullname_persona
              && i.is_user == false)
            {
              this._found_not_user = true;
            }
          else if (i.is_user == true)
            {
              this._found_default_user = true;
            }
          else
            {
              this._found_unknown_user = true;
            }
        }

        if (this._found_not_user &&
            this._found_default_user)
          this._main_loop.quit ();

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

  var tests = new DefaultContactTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
