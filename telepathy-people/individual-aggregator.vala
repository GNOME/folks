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
using Tpp.PersonaStore;

public class Tpp.IndividualAggregator : Object
{
  private HashMap<string, PersonaStore> stores;

  public signal void individuals_added (GLib.List<Individual> inds);

  public IndividualAggregator ()
    {
      var manager = AccountManager.dup ();
      unowned GLib.List<Account> accounts = manager.get_valid_accounts ();
      this.stores = new HashMap<string, PersonaStore> ();

      foreach (Account account in accounts)
        {
          var store = new PersonaStore (account);
          this.stores.set (account.get_object_path (account), store);
        }

      /* FIXME: cut this block */
      debug ("the accounts we've got:");
      foreach (var entry in this.stores)
        {
          PersonaStore store = entry.value;
          debug ("     account name: '%s'", store.account.get_display_name ());

          store.personas_added.connect (this.personas_added_cb);
        }

      /* FIXME: react to accounts being created and deleted */
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

      individuals.reverse ();
      this.individuals_added (individuals);

      /* FIXME: add these individuals to an internal store */
    }
}
