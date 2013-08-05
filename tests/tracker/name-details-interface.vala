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

public class NameDetailsInterfaceTests : TrackerTest.TestCase
{
  private IndividualAggregator _aggregator;
  private GLib.MainLoop _main_loop;
  private Gee.HashMap<string, string> _c1;
  private Gee.HashMap<string, string> _c2;

  public NameDetailsInterfaceTests ()
    {
      base ("NameDetailsInterfaceTests");

      this.add_test ("test name details interface",
          this.test_name_details_interface);
    }

  public void test_name_details_interface ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._c1 = new Gee.HashMap<string, string> ();
      this._c2 = new Gee.HashMap<string, string> ();

      this._c1.set (Trf.OntologyDefs.NCO_FULLNAME, "persona #1");
      this._c1.set (Trf.OntologyDefs.NCO_FAMILY, "p #1 Family");
      this._c1.set (Trf.OntologyDefs.NCO_GIVEN, "p #1 Given");
      this._c1.set (Trf.OntologyDefs.NCO_ADDITIONAL, "p #1 Additional");
      this._c1.set (Trf.OntologyDefs.NCO_PREFIX, "Mr");
      this._c1.set (Trf.OntologyDefs.NCO_SUFFIX, "Jr");
      ((!) this.tracker_backend).add_contact (this._c1);

      this._c2.set (Trf.OntologyDefs.NCO_FULLNAME, "persona #2");
      ((!) this.tracker_backend).add_contact (this._c2);

      ((!) this.tracker_backend).set_up ();

      this._test_name_details_interface_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._c1.size == 0);
      assert (this._c2.size == 0);
    }

  private async void _test_name_details_interface_async ()
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

          string full_name = ((Folks.NameDetails) i).full_name;
          if (full_name != null)
            {
              StructuredName sname =
                  ((Folks.NameDetails) i).structured_name;

               if (full_name == "persona #1")
                 {
                   this._c1.unset (Trf.OntologyDefs.NCO_FULLNAME);

                   string family = sname.family_name ;
                   assert (this._c1.get (Trf.OntologyDefs.NCO_FAMILY) ==
                       family);
                   this._c1.unset (Trf.OntologyDefs.NCO_FAMILY);

                   string given = sname.given_name;
                   assert (this._c1.get (Trf.OntologyDefs.NCO_GIVEN) == given);
                   this._c1.unset (Trf.OntologyDefs.NCO_GIVEN);

                   string additional = sname.additional_names;
                   assert (this._c1.get (Trf.OntologyDefs.NCO_ADDITIONAL) ==
                       additional);
                   this._c1.unset (Trf.OntologyDefs.NCO_ADDITIONAL);

                   string prefix = sname.prefixes;
                   assert (this._c1.get (Trf.OntologyDefs.NCO_PREFIX) ==
                       prefix);
                   this._c1.unset (Trf.OntologyDefs.NCO_PREFIX);

                   string suffix = sname.suffixes;
                   assert (this._c1.get (Trf.OntologyDefs.NCO_SUFFIX) ==
                       suffix);
                   this._c1.unset (Trf.OntologyDefs.NCO_SUFFIX);

                   assert (sname.is_empty () == false);
                 }
               else if (full_name == "persona #2")
                 {
                   this._c2.unset (Trf.OntologyDefs.NCO_FULLNAME);

                   assert (sname == null || sname.is_empty () == true);
                 }
            }
        }

      if (this._c1.size == 0 &&
          this._c2.size == 0)
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

  var tests = new NameDetailsInterfaceTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
