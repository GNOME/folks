/*
 * Copyright (C) 2011, 2015 Collabora Ltd.
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
 *          Philip Withnall <philip.withnall@collabora.co.uk>
 *
 */

using EdsTest;
using Folks;
using Gee;

public class IndividualRetrievalTests : EdsTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private HashSet<string> _found_individuals;

  public IndividualRetrievalTests ()
    {
      base ("IndividualRetrieval");

      this.add_test ("singleton individuals", this.test_singleton_individuals);
    }

  public void test_singleton_individuals ()
    {
      Gee.HashMap<string, Value?> c1 = new Gee.HashMap<string, Value?> ();
      Gee.HashMap<string, Value?> c2 = new Gee.HashMap<string, Value?> ();
      this._found_individuals = new HashSet<string> ();
      this._main_loop = new GLib.MainLoop (null, false);
      Value? v;

      this.eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      c1.set("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("bernie@example.org");
      c1.set(Edsf.Persona.email_fields[0], (owned) v);
      this.eds_backend.add_contact (c1);

      v = Value (typeof (string));
      v.set_string ("richard m. stallman");
      c2.set("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("rms@example.org");
      c2.set(Edsf.Persona.email_fields[0], (owned) v);
      this.eds_backend.add_contact (c2);

      this._test_singleton_individuals_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_individuals.size == 2);
    }

  private async void _test_singleton_individuals_async ()
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

          assert (i.personas.size == 1);
          this._found_individuals.add (i.id);
        }

      if (this._found_individuals.size == 2)
        {
          this._main_loop.quit ();
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

  var tests = new IndividualRetrievalTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
