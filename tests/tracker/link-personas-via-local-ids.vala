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

public class LinkPersonasViaLocalIDsTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private string _persona_fullname_1;
  private string _persona_fullname_2;
  private bool _linking_fired;
  private bool _persona_found_1;
  private bool _persona_found_2;
  private string _persona_uid_1 = "";
  private string _persona_uid_2 = "";
  private GLib.List<Persona> _personas;
  private int _removed_individuals = 0;
  private string _folks_config_key = "/system/folks/backends/primary_store";
  private unowned GConf.Client _gconf_client;
  private Gee.HashSet<string> _local_ids;

  public LinkPersonasViaLocalIDsTests ()
    {
      base ("LinkPersonasViaLocalIDsTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test linking personas",
          this.test_linking_personas_via_local_ids);
    }

  public override void set_up ()
    {
      this._gconf_client = GConf.Client.get_default ();

      /* We configure Tracker as the primary (writeable) store by
       * setting the appropiate GConf key. */
      try
        {
          GConf.Value val = new GConf.Value (GConf.ValueType.STRING);
          val.set_string ("tracker");
          this._gconf_client.set (this._folks_config_key, val);
        }
      catch (GLib.Error e)
        {
          warning ("Couldn't set primary store: %s\n", e.message);
        }

      /* FIXME: this set_up method takes care both of setting
       * the connection with Tracker and adding the contacts
       * needed for the tests. We might need to trigger those
       * actions at separate points so we should decouple them. */
      this._tracker_backend.set_up ();
    }

  public override void tear_down ()
    {
      this._tracker_backend.tear_down ();

      /* Clean-up GConf config (although we are running our own instance
       * lets do the house-keeping anyways). */
      try
        {
          this._gconf_client.unset (this._folks_config_key);
        }
      catch (GLib.Error e)
        {
          warning ("Couldn't unset primary store: %s\n", e.message);
        }
    }

  public void test_linking_personas_via_local_ids ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._persona_fullname_1 = "persona #1";
      this._persona_fullname_2 = "persona #2";
      this._personas = new GLib.List<Persona> ();

      this._persona_found_1 = false;
      this._persona_found_2 = false;
      this._linking_fired = false;

      this._local_ids = new Gee.HashSet <string> ();

      this._test_linking_personas_via_local_ids_async ();

      /* Kill the main loop after 8 seconds: if the linked individual hasn't
       * show up at this point then we've either seen an error or we've been
       * too slow (which we can consider to be failure). */
      Timeout.add_seconds (8, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      /* Check we get the new individual (containing the linked
       * personas) and that the previous ones were removed. */
      assert (this._local_ids.size == 0);
      assert (this._removed_individuals == 2);
    }

  private async void _test_linking_personas_via_local_ids_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = new IndividualAggregator ();
      this._aggregator.individuals_changed.connect
          (this._individuals_changed_cb);
      try
        {
          yield this._aggregator.prepare ();

          PersonaStore pstore = null;
          foreach (var backend in store.enabled_backends)
            {
              pstore = backend.persona_stores.lookup ("tracker");
              if (pstore != null)
                break;
            }
          assert (pstore != null);

          yield _add_personas (pstore);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }
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

  private void _individuals_changed_cb
      (GLib.List<Individual>? added,
       GLib.List<Individual>? removed,
       string? message,
       Persona? actor,
       GroupDetails.ChangeReason reason)
    {
      foreach (unowned Individual i in added)
        {
          /* Lets listen to notifications from those individuals
           * which aren't the default (Tracker) user */
          if (!i.is_user)
            {
              i.notify["full-name"].connect (this._notify_cb);
              i.notify["local-ids"].connect (this._notify_cb);
              this._check_personas (i);
            }
        }

      if (removed != null)
        this._removed_individuals += (int) removed.length ();
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
      if (i.full_name == this._persona_fullname_1 &&
          this._persona_uid_1 == "")
        {
          this._persona_uid_1 = i.personas.nth_data (0).uid;
          this._personas.prepend (i.personas.nth_data (0));
          this._local_ids.add (this._persona_uid_1);
        }
      else if (i.full_name == this._persona_fullname_2 &&
          this._persona_uid_2 == "")
        {
          this._persona_uid_2 = i.personas.nth_data (0).uid;
          this._personas.prepend (i.personas.nth_data (0));
          this._local_ids.add (this._persona_uid_2);
        }
      else if (i.personas.length () > 1)
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
      if (this._personas.length () == 2 &&
          this._linking_fired == false)
        {
          this._linking_fired = true;

          /* FIXME: we need a way to sync with Tracker
           * delayed events. */
          Timeout.add_seconds (2, () =>
            {
              this._aggregator.link_personas (this._personas);
              return false;
            });
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new LinkPersonasViaLocalIDsTests ().get_suite ());

  Test.run ();

  return 0;
}
