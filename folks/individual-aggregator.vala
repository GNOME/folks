/*
 * Copyright (C) 2010 Collabora Ltd.
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
 * Authors:
 *       Travis Reitter <travis.reitter@collabora.co.uk>
 */

using GLib;
using Gee;
using Tp;
using Folks.PersonaStore;
using Folks.TpPersonaStore;

public class Folks.IndividualAggregator : Object
{
  private AccountManager account_manager;
  private HashMap<string, PersonaStore> stores;

  public HashTable<Individual, uint> members { get; private set; }

  public signal void individuals_added (GLib.List<Individual> inds);
  /* TODO: add a signal for "subcontact went offline/online"? Is that useful
   * enough to bother with? */

  /* FIXME: make this a singleton? */
  public IndividualAggregator () throws GLib.Error
    {
      this.stores = new HashMap<string, PersonaStore> ();
      this.members = new HashTable<Individual, uint>.full (direct_hash,
          direct_equal, g_object_unref, null);

      this.setup_account_manager ();
    }

  private async void setup_account_manager () throws GLib.Error
    {
      this.account_manager = AccountManager.dup ();
      yield this.account_manager.prepare_async (null);
      this.account_manager.account_enabled.connect (this.account_enabled_cb);

      /* FIXME: react to accounts being deleted, invalidated, etc. */

      unowned GLib.List<Account> accounts =
          this.account_manager.get_valid_accounts ();
      foreach (Account account in accounts)
        {
          this.account_enabled_cb (account);
        }
    }

  private void account_enabled_cb (Account account)
    {
      var store = new TpPersonaStore (account);

      /* FIXME: cut this */
      debug ("   adding account name: '%s'", store.account.get_display_name ());

      store.personas_added.connect (this.personas_added_cb);
      this.stores.set (account.get_object_path (account), store);
    }

  private void personas_added_cb (PersonaStore store,
      GLib.List<Persona> personas)
    {
      var individuals = new GLib.List<Individual> ();
      personas.foreach ((persona) =>
        {
          var p = (Persona) persona;

          /* FIXME: correlate the new personas with each other and
            * the existing personas and existing Individuals;
            * update existing Individuals and create new ones as
            * necessary */

          var grouped_personas = new GLib.List<Persona> ();
          grouped_personas.prepend (p);
          var individual = new Individual (grouped_personas);
          individuals.prepend (individual);
        });

      GLib.List<Individual> new_individuals = null;
      foreach (var i in individuals)
        {
          if (this.members.lookup (i) == 0)
            {
              new_individuals.prepend (i);
              this.members.insert (i, 1);
            }
        }

      if (new_individuals != null)
        {
          new_individuals.reverse ();
          this.individuals_added (new_individuals);
        }
    }
}
