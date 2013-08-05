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

public class LinkPersonasViaLocalIDsTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _persona_fullname_1;
  private string _persona_fullname_2;
  private bool _linking_fired;
  private bool _persona_found_1;
  private bool _persona_found_2;
  private string _persona_iid_1 = "";
  private string _persona_iid_2 = "";
  private HashSet<Persona> _personas;
  private int _removed_individuals = 0;
  private Gee.HashSet<string> _local_ids;

  public LinkPersonasViaLocalIDsTests ()
    {
      base ("LinkPersonasViaLocalIDsTests");

      this.add_test ("test linking personas",
          this.test_linking_personas_via_local_ids);
    }

  public override void set_up ()
    {
      base.set_up ();

      Environment.set_variable ("FOLKS_PRIMARY_STORE", "tracker", true);

      /* FIXME: this set_up method takes care both of setting
       * the connection with Tracker and adding the contacts
       * needed for the tests. We might need to trigger those
       * actions at separate points so we should decouple them. */
      ((!) this.tracker_backend).set_up ();
    }

  public override void tear_down ()
    {
      Environment.unset_variable ("FOLKS_PRIMARY_STORE");
      base.tear_down ();
    }

  public void test_linking_personas_via_local_ids ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._persona_fullname_1 = "persona #1";
      this._persona_fullname_2 = "persona #2";
      this._personas = new HashSet<Persona> ();

      this._persona_found_1 = false;
      this._persona_found_2 = false;
      this._linking_fired = false;

      this._local_ids = new Gee.HashSet <string> ();

      this._test_linking_personas_via_local_ids_async.begin ();

      /* Kill the main loop after 8 seconds: if the linked individual hasn't
       * show up at this point then we've either seen an error or we've been
       * too slow (which we can consider to be failure). */
      TestUtils.loop_run_with_timeout (this._main_loop, 8);

      /* Check we get the new individual (containing the linked
       * personas) and that the previous ones were removed. */
      assert (this._local_ids.size == 0);
      assert (this._removed_individuals == 2);
    }

  private async void _test_linking_personas_via_local_ids_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = IndividualAggregator.dup ();
      this._aggregator.individuals_changed_detailed.connect
          (this._individuals_changed_cb);
      try
        {
          yield this._aggregator.prepare ();

          PersonaStore pstore = null;
          foreach (var backend in store.enabled_backends.values)
            {
              pstore = backend.persona_stores.get ("tracker");
              if (pstore != null)
                break;
            }
          assert (pstore != null);
          pstore.notify["is-prepared"].connect (this._persona_store_prepared_cb);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }
    }

  private void _persona_store_prepared_cb (Object obj, ParamSpec params)
    {
      PersonaStore pstore = (!)(obj as PersonaStore);
      
      _add_personas.begin (pstore);
    }

  /* Here is how this test is expected to work:
   * - we start by adding 2 personas
   * - this should trigger individuals-changed with 2 new individuals
   * - we ask the IndividualAggregator to link the 2 personas coming
   *   from those individuals
   * - we wait for a new Individual which contains the linkable
   *   attributes of these 2 personas
   */
  private async void _add_personas (PersonaStore pstore)
    {
      HashTable<string, Value?> details1 = new HashTable<string, Value?>
          (str_hash, str_equal);
      Value? v1 = Value (typeof (string));
      v1.set_string (this._persona_fullname_1);
      details1.insert ("full-name", (owned) v1);

      HashTable<string, Value?> details2 = new HashTable<string, Value?>
          (str_hash, str_equal);
      Value? v2 = Value (typeof (string));
      v2.set_string (this._persona_fullname_2);
      details2.insert ("full-name", (owned)v2);

      try
        {
          yield this._aggregator.add_persona_from_details (null,
              pstore, details1);

          yield this._aggregator.add_persona_from_details (null,
              pstore, details2);
        }
      catch (Folks.IndividualAggregatorError e)
        {
          GLib.warning ("[AddPersonaError] add_persona_from_details: %s\n",
              e.message);
        }
    }

  private void _individuals_changed_cb (
       MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();
      var removed = changes.get_keys ();

      foreach (var i in added)
        {
          if (i == null)
            {
              continue;
            }

          /* Lets listen to notifications from those individuals
           * which aren't the default (Tracker) user */
          if (!i.is_user)
            {
              i.notify["full-name"].connect (this._notify_cb);
              i.notify["local-ids"].connect (this._notify_cb);
              this._check_personas (i);
            }
        }

      foreach (var i in removed)
        {
          if (i == null)
            {
              continue;
            }

          this._removed_individuals++;
        }
    }

  private void _notify_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      this._check_personas (i);
    }

  /* As mentioned in _add_personas here we actually check
   * for the following events
   *
   * - spot the 2 individuals corresponding to the 2 personas we've added
   * - when we've spotted these 2, we pack them in a list and feed that to
   *   IndividualAggregator#link_personas
   * - this should fire a new individuals-changed event with a new individual
   *   which should be the linked individual if it contains the linking
   *   properties of the 2 linked personas.
   */
  private void _check_personas (Individual i)
    {
      Persona first_persona = null;
      foreach (var p in i.personas)
        {
          first_persona = p;
          break;
        }

      if (i.full_name == this._persona_fullname_1 &&
          this._persona_iid_1 == "")
        {
          this._persona_iid_1 = first_persona.iid;
          this._personas.add (first_persona);
          this._local_ids.add (this._persona_iid_1);
        }
      else if (i.full_name == this._persona_fullname_2 &&
          this._persona_iid_2 == "")
        {
          this._persona_iid_2 = first_persona.iid;
          this._personas.add (first_persona);
          this._local_ids.add (this._persona_iid_2);
        }
      else if (i.personas.size > 1)
        {
          /* Lets check if it contains all the linking properties */
          foreach (var id in i.local_ids)
            {
              if (this._local_ids.contains (id))
                {
                  this._local_ids.remove (id);
                }
            }

          if (this._local_ids.size == 0)
            {
              this._main_loop.quit ();
            }
        }

      /* We can try linking the personas only once we've got the
       * 2 initially created personas. */
      if (this._personas.size == 2 &&
          this._linking_fired == false)
        {
          this._linking_fired = true;

          /* FIXME: we need a way to sync with Tracker
           * delayed events. */
          Timeout.add_seconds (2, () =>
            {
              this._aggregator.link_personas.begin (this._personas);
              return false;
            });
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new LinkPersonasViaLocalIDsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
