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

using Folks;
using Gee;
using GLib;

/**
 * Errors from {@link IndividualAggregator}s.
 */
public errordomain Folks.IndividualAggregatorError
{
  /**
   * A specified {@link PersonaStore} could not be found.
   */
  STORE_NOT_FOUND,

  /**
   * Adding a {@link Persona} to a {@link PersonaStore} failed.
   */
  ADD_FAILED,
}

/**
 * Allows access to the {@link Individual}s which have been created through
 * aggregation of all the {@link Persona}s provided by the various
 * {@link Backend}s. This is the main interface for client applications.
 */
public class Folks.IndividualAggregator : Object
{
  private BackendStore backend_store;
  private HashMap<string, PersonaStore> stores;
  private HashSet<Backend> backends;

  /**
   * A table mapping {@link Individual.id}s to their {@link Individual}s.
   *
   * This is the canonical set of {@link Individual}s provided by this
   * IndividualAggregator.
   *
   * {@link Individual}s may be added or removed using
   * {@link IndividualAggregator.add_persona_from_details} and
   * {@link IndividualAggregator.remove_individual}, respectively.
   */
  public HashTable<string, Individual> members { get; private set; }

  /**
   * Emitted when one or more {@link Individual}s are added to the aggregator.
   *
   * @param inds a list of {@link Individual}s which have been added
   */
  public signal void individuals_added (GLib.List<Individual> inds);

  /**
   * Emitted when one or more {@link Individual}s are removed from the
   * aggregator.
   *
   * @param inds a list of {@link Individual}s which have been removed
   */
  public signal void individuals_removed (GLib.List<Individual> inds);

  /* FIXME: make this a singleton? */
  /**
   * Create a new IndividualAggregator.
   *
   * Clients should connect to the
   * {@link IndividualAggregator.individuals_added} and
   * {@link IndividualAggregator.individuals_removed} signals, which will be
   * emitted as soon as the {@link Backend}s are loaded and {@link Persona}s
   * found.
   *
   * FIXME: Race condition when connecting to signals?
   */
  public IndividualAggregator ()
    {
      this.stores = new HashMap<string, PersonaStore> ();
      this.members = new HashTable<string, Individual> (str_hash, str_equal);

      this.backends = new HashSet<Backend> ();

      this.backend_store = new BackendStore ();
      this.backend_store.backend_available.connect (this.backend_available_cb);
      this.backend_store.load_backends ();
    }

  private void backend_available_cb (BackendStore backend_store,
      Backend backend)
    {
      backend.persona_store_added.connect (this.backend_persona_store_added_cb);
      backend.persona_store_removed.connect (
          this.backend_persona_store_removed_cb);
    }

  private void backend_persona_store_added_cb (Backend backend,
      PersonaStore store)
    {
      this.stores.set (this.get_store_full_id (store.type_id, store.id), store);
      store.personas_added.connect (this.personas_added_cb);
    }

  private void backend_persona_store_removed_cb (Backend backend,
      PersonaStore store)
    {
      store.personas_added.disconnect (this.personas_added_cb);

      /* no need to remove this stores' personas from all the individuals, since
       * they'll do that themselves (and emit their own 'removed' signal if
       * necessary) */

      this.stores.unset (this.get_store_full_id (store.type_id, store.id));
    }

  private string get_store_full_id (string type_id, string id)
    {
      return type_id + ":" + id;
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

      /* For each of the individuals constructed from the newly added personas,
       * if they don't exist in the aggregator's list of member individuals,
       * add them to it. */
      GLib.List<Individual> new_individuals = null;
      foreach (var i in individuals)
        {
          if (this.members.lookup (i.id) == null)
            {
              i.removed.connect (this.individual_removed_cb);
              new_individuals.prepend (i);
              this.members.insert (i.id, i);
            }
        }

      /* Signal the addition of new individuals to the aggregator */
      if (new_individuals != null)
        {
          new_individuals.reverse ();
          this.individuals_added (new_individuals);
        }
    }

  private void individual_removed_cb (Individual i)
    {
      var i_list = new GLib.List<Individual> ();
      i_list.append (i);

      this.individuals_removed (i_list);
      this.members.remove (i.id);
    }

  /**
   * Add a new persona in the given {@link PersonaStore} based on the `details`
   * provided.
   *
   * The details hash is a backend-specific mapping of key, value strings.
   * Common keys include:
   *
   *  * contact - service-specific contact ID
   *
   * If `parent` is provided, the new persona will be appended to its ordered
   * list of personas.
   *
   * @param parent an optional {@link Individual} to add the new {@link Persona}
   * to
   * @param persona_store_type the {@link PersonaStore.type_id} of the
   * {@link PersonaStore} to use
   * @param persona_store_id the {@link PersonaStore.id} of the
   * {@link PersonaStore} to use
   * @param details a key-value map of details to use in creating the new
   * {@link Persona}
   */
  public async Persona? add_persona_from_details (Individual? parent,
      string persona_store_type,
      string persona_store_id,
      HashTable<string, string> details) throws IndividualAggregatorError
    {
      var full_id = this.get_store_full_id (persona_store_type,
          persona_store_id);
      var store = this.stores[full_id];

      if (store == null)
        {
          throw new IndividualAggregatorError.STORE_NOT_FOUND (
              "no store known for type ID '%s' and ID '%s'", store.type_id,
              store.id);
        }

      Persona persona = null;
      try
        {
          persona = yield store.add_persona_from_details (details);
        }
      catch (PersonaStoreError e)
        {
          throw new IndividualAggregatorError.ADD_FAILED (
              "failed to add contact for store type '%s', ID '%s': %s",
              persona_store_type, persona_store_id, e.message);
        }

      if (parent != null)
        {
          var personas = parent.personas.copy ();

          personas.append (persona);
          parent.personas = personas;
        }

      return persona;
    }

  /**
   * Completely remove the individual and all of its personas from their
   * backing stores.
   *
   * @param individual the {@link Individual} to remove
   */
  public void remove_individual (Individual individual)
    {
      individual.personas.foreach ((p) =>
        {
          var persona = (Persona) p;
          persona.store.remove_persona (persona);
        });
    }
}
