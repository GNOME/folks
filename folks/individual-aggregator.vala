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

  /**
   * An operation which required the use of a writeable store failed because no
   * writeable store was available.
   */
  NO_WRITEABLE_STORE,
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
  private unowned PersonaStore writeable_store;
  private HashSet<Backend> backends;
  private HashTable<string, Individual> link_map;

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
  public HashTable<string, Individual> individuals { get; private set; }

  /**
   * Emitted when one or more {@link Individual}s are added to or removed from
   * the aggregator.
   *
   * This will not be emitted until after {@link IndividualAggregator.prepare}
   * has been called.
   *
   * @param added a list of {@link Individual}s which have been removed
   * @param removed a list of {@link Individual}s which have been removed
   * @param message a string message from the backend, if any
   * @param actor the {@link Persona} who made the change, if known
   * @param reason the reason for the change
   */
  public signal void individuals_changed (GLib.List<Individual>? added,
      GLib.List<Individual>? removed,
      string? message,
      Persona? actor,
      Groups.ChangeReason reason);

  /* FIXME: make this a singleton? */
  /**
   * Create a new IndividualAggregator.
   *
   * Clients should connect to the
   * {@link IndividualAggregator.individuals_changed} signal, then call
   * {@link IndividualAggregator.prepare} to load the backends and start
   * aggregating individuals.
   *
   * An example of how to set up an IndividualAggregator:
   * {{{
   *   IndividualAggregator agg = new IndividualAggregator ();
   *   agg.individuals_changed.connect (individuals_changed_cb);
   *   agg.prepare ();
   * }}}
   */
  public IndividualAggregator ()
    {
      this.stores = new HashMap<string, PersonaStore> ();
      this.individuals = new HashTable<string, Individual> (str_hash,
          str_equal);
      this.link_map = new HashTable<string, Individual> (str_hash, str_equal);

      this.backends = new HashSet<Backend> ();

      Debug.set_flags (Environment.get_variable ("FOLKS_DEBUG"));

      this.backend_store = new BackendStore ();
      this.backend_store.backend_available.connect (this.backend_available_cb);
    }

  /**
   * Prepare the IndividualAggregator for use.
   *
   * This loads all the available backends and prepares them for use by the
   * IndividualAggregator. This should be called //after// connecting to the
   * {@link IndividualAggregator.individuals_changed} signal, or a race
   * condition could occur, with the signal being emitted before your code has
   * connected to them, and {@link Individual}s getting "lost" as a result.
   */
  public async void prepare () throws GLib.Error
    {
      this.backend_store.load_backends ();
    }

  private void backend_available_cb (BackendStore backend_store,
      Backend backend)
    {
      backend.persona_store_added.connect (this.backend_persona_store_added_cb);
      backend.persona_store_removed.connect (
          this.backend_persona_store_removed_cb);

      backend.prepare.begin ((obj, result) =>
        {
          try
            {
              backend.prepare.end (result);
            }
          catch (GLib.Error e)
            {
              warning ("Error preparing Backend '%s': %s", backend.name,
                  e.message);
            }
        });
    }

  private void backend_persona_store_added_cb (Backend backend,
      PersonaStore store)
    {
      string store_id = this.get_store_full_id (store.type_id, store.id);

      /* FIXME: We hardcode the key-file backend's singleton PersonaStore as the
       * only trusted and writeable PersonaStore for now. */
      if (store.type_id == "key-file")
        {
          store.is_writeable = true;
          store.trust_level = PersonaStoreTrust.FULL;
          this.writeable_store = store;
        }

      this.stores.set (store_id, store);
      store.personas_changed.connect (this.personas_changed_cb);
      store.notify["is-writeable"].connect (this.is_writeable_changed_cb);
      store.notify["trust-level"].connect (this.trust_level_changed_cb);

      store.prepare.begin ((obj, result) =>
        {
          try
            {
              store.prepare.end (result);
            }
          catch (GLib.Error e)
            {
              warning ("Error preparing PersonaStore '%s': %s", store_id,
                  e.message);
            }
        });
    }

  private void backend_persona_store_removed_cb (Backend backend,
      PersonaStore store)
    {
      store.personas_changed.disconnect (this.personas_changed_cb);
      store.notify["trust-level"].disconnect (this.trust_level_changed_cb);
      store.notify["is-writeable"].disconnect (this.is_writeable_changed_cb);

      /* no need to remove this store's personas from all the individuals, since
       * they'll do that themselves (and emit their own 'removed' signal if
       * necessary) */

      if (this.writeable_store == store)
        this.writeable_store = null;
      this.stores.unset (this.get_store_full_id (store.type_id, store.id));
    }

  private string get_store_full_id (string type_id, string id)
    {
      return type_id + ":" + id;
    }

  private void personas_changed_cb (PersonaStore store,
      GLib.List<Persona>? added,
      GLib.List<Persona>? removed,
      string? message,
      Persona? actor,
      Groups.ChangeReason reason)
    {
      GLib.List<Individual> new_individuals = new GLib.List<Individual> ();

      added.foreach ((p) =>
        {
          unowned Persona persona = (Persona) p;
          PersonaStoreTrust trust_level = persona.store.trust_level;
          GLib.List<Individual> candidate_inds = null;
          GLib.List<Persona> final_personas = new GLib.List<Persona> ();
          Individual final_individual = null;

          debug ("Aggregating persona '%s' on '%s'.", persona.uid, persona.iid);

          /* If we don't trust the PersonaStore at all, we can't link the
           * Persona to any existing Individual */
          if (trust_level != PersonaStoreTrust.NONE)
            {
              Individual candidate_ind = this.link_map.lookup (persona.iid);
              if (candidate_ind != null)
                {
                  debug ("    Found candidate individual '%s' by IID.",
                      candidate_ind.id);
                  candidate_inds.prepend (candidate_ind);
                }
            }

          if (persona.store.trust_level == PersonaStoreTrust.FULL)
            {
              /* If we trust the PersonaStore the Persona came from, we can
               * attempt to link based on its linkable properties. */
              foreach (string prop_name in persona.linkable_properties)
                {
                  unowned ObjectClass pclass = persona.get_class ();
                  if (pclass.find_property (prop_name) == null)
                    {
                      warning ("Unknown property '%s' in linkable property " +
                          "list.", prop_name);
                      continue;
                    }

                  persona.linkable_property_to_links (prop_name, (l) =>
                    {
                      Individual candidate_ind =
                          this.link_map.lookup ((string) l);
                      if (candidate_ind != null)
                        candidate_inds.prepend (candidate_ind);
                    });
                }
            }

          /* Ensure the original persona makes it into the final persona */
          final_personas.prepend (persona);

          if (candidate_inds != null)
            {
              debug ("    Found candidate individuals:");

              /* The Persona's IID or linkable properties match one or more
               * linkable fields which are already in the link map, so we link
               * together all the Individuals we found to form a new
               * final_individual. Later, we remove the Personas from the old
               * Individuals so that the Individuals themselves are removed. */
              candidate_inds.foreach ((i) =>
                {
                  unowned Individual individual = (Individual) i;

                  debug ("        %s", individual.id);

                  /* FIXME: It would be faster to prepend a reversed copy of
                   * `individual.personas`, then reverse the entire
                   * `final_personas` list afterwards, but Vala won't let us.
                   * We also have to reference each of `individual.personas`
                   * manually, since copy() doesn't do that for us. */
                  individual.personas.foreach ((p) =>
                    {
                      ((Persona) p).ref ();
                    });

                  final_personas.concat (individual.personas.copy ());
                });
            }
          else
            {
              debug ("    Did not find any candidate individuals.");
            }

          /* Create the final linked Individual */
          final_individual = new Individual (final_personas);

          debug ("    Created new individual '%s' with personas:",
              final_individual.id);
          final_personas.foreach ((i) =>
            {
              unowned Persona final_persona = (Persona) i;

              debug ("        %s", final_persona.uid);

              /* Only add the Persona to the link map if we trust its IID. */
              if (trust_level != PersonaStoreTrust.NONE)
                this.link_map.replace (final_persona.iid, final_individual);

              /* Only allow linking on non-IID properties of the Persona if we
               * fully trust the PersonaStore it came from. */
              if (final_persona.store.trust_level == PersonaStoreTrust.FULL)
                {
                  /* Insert maps from the Persona's linkable properties to the
                   * Individual. */
                  foreach (string prop_name in
                      final_persona.linkable_properties)
                    {
                      unowned ObjectClass pclass = final_persona.get_class ();
                      if (pclass.find_property (prop_name) == null)
                        {
                          warning ("Unknown property '%s' in linkable " +
                              "property list.", prop_name);
                          continue;
                        }

                      final_persona.linkable_property_to_links (prop_name,
                          (l) =>
                        {
                          this.link_map.replace ((string) l, final_individual);
                        });
                    }
                }
            });

          /* Remove the old Individuals. This has to be done here, as we need
           * the final_individual. */
          candidate_inds.foreach ((i) =>
            {
              ((Individual) i).replace (final_individual);
            });

          /* Add the new Individual to the aggregator */
          final_individual.removed.connect (this.individual_removed_cb);
          new_individuals.prepend (final_individual);
          this.individuals.insert (final_individual.id, final_individual);
        });

      removed.foreach ((p) =>
        {
          unowned Persona persona = (Persona) p;
          PersonaStoreTrust trust_level = persona.store.trust_level;

          if (trust_level != PersonaStoreTrust.NONE)
            this.link_map.remove (persona.iid);

          if (trust_level == PersonaStoreTrust.FULL)
            {
              /* Remove maps from the Persona's linkable properties to the
               * Individual. */
              foreach (string prop_name in persona.linkable_properties)
                {
                  unowned ObjectClass pclass = persona.get_class ();
                  if (pclass.find_property (prop_name) == null)
                    {
                      warning ("Unknown property '%s' in linkable property " +
                          "list.", prop_name);
                      continue;
                    }

                  persona.linkable_property_to_links (prop_name, (l) =>
                    {
                     this.link_map.remove ((string) l);
                   });
                }
            }
        });

      /* Signal the addition of new individuals to the aggregator */
      if (new_individuals != null)
        {
          new_individuals.reverse ();
          this.individuals_changed (new_individuals, null, null, null, 0);
        }
    }

  private void is_writeable_changed_cb (Object object, ParamSpec pspec)
    {
      /* Ensure that we only have one writeable PersonaStore */
      unowned PersonaStore store = (PersonaStore) object;
      assert ((store.is_writeable == true && store == this.writeable_store) ||
          (store.is_writeable == false && store != this.writeable_store));
    }

  private void trust_level_changed_cb (Object object, ParamSpec pspec)
    {
      /* FIXME: For the moment, assert that only the key-file backend's
       * singleton PersonaStore is trusted. */
      unowned PersonaStore store = (PersonaStore) object;
      if (store.type_id == "key-file")
        assert (store.trust_level == PersonaStoreTrust.FULL);
      else
        assert (store.trust_level != PersonaStoreTrust.FULL);
    }

  private void individual_removed_cb (Individual i, Individual? replacement)
    {
      var i_list = new GLib.List<Individual> ();
      i_list.append (i);

      this.individuals_changed (null, i_list, null, null, 0);
      this.individuals.remove (i.id);
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
      HashTable<string, Value?> details) throws IndividualAggregatorError
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
          var details_copy = asv_copy (details);
          persona = yield store.add_persona_from_details (details_copy);
        }
      catch (PersonaStoreError e)
        {
          throw new IndividualAggregatorError.ADD_FAILED (
              "failed to add contact for store type '%s', ID '%s': %s",
              persona_store_type, persona_store_id, e.message);
        }

      if (parent != null && persona != null)
        {
          var personas = parent.personas.copy ();

          personas.append (persona);
          parent.personas = personas;
        }

      return persona;
    }

  private HashTable<string, Value?> asv_copy (HashTable<string, Value?> asv)
    {
      var retval = new HashTable<string, Value?> (str_hash, str_equal);

      asv.foreach ((k, v) =>
        {
          retval.insert ((string) k, (Value?) v);
        });

      return retval;
    }

  /**
   * Completely remove the individual and all of its personas from their
   * backing stores.
   *
   * @param individual the {@link Individual} to remove
   */
  public async void remove_individual (Individual individual) throws GLib.Error
    {
      /* We have to iterate manually since using foreach() requires a sync
       * lambda function, meaning we can't yield on the remove_persona() call */
      unowned GLib.List<unowned Persona> i;
      for (i = individual.personas; i != null; i = i.next)
        {
          unowned Persona persona = (Persona) i.data;
          yield persona.store.remove_persona (persona);
        }
    }

  /**
   * Completely remove the persona from its backing store.
   *
   * This will leave other personas in the same individual alone.
   *
   * @param persona the {@link Persona} to remove
   */
  public async void remove_persona (Persona persona) throws GLib.Error
    {
      yield persona.store.remove_persona (persona);
    }

  /* FIXME: This should be GLib.List<Persona>, but Vala won't allow it */
  public async void link_personas (void *_personas)
      throws GLib.Error
    {
      unowned GLib.List<Persona> personas = (GLib.List<Persona>) _personas;

      if (this.writeable_store == null)
        {
          throw new IndividualAggregatorError.NO_WRITEABLE_STORE (
              "Can't link personas with no writeable store.");
        }

      /* Don't bother linking if it's just one Persona */
      if (personas.next == null)
        return;

      /* Create a new persona in the writeable store which links together the
       * given personas */
      /* FIXME: We hardcode this to use the key-file backend for now */
      assert (this.writeable_store.type_id == "key-file");

      HashTable<string, GenericArray<string>> protocols =
          new HashTable<string, GenericArray<string>> (str_hash, str_equal);
      personas.foreach ((p) =>
        {
          unowned Persona persona = (Persona) p;

          if (!(Persona is IMable))
            return;

          ((IMable) persona).im_addresses.foreach ((k, v) =>
            {
              unowned string protocol = (string) k;
              unowned GenericArray<string> addresses = (GenericArray<string>) v;

              GenericArray<string> existing_addresses =
                  protocols.lookup (protocol);
              if (existing_addresses == null)
                {
                  existing_addresses = new GenericArray<string> ();
                  protocols.insert (protocol, existing_addresses);
                }

              addresses.foreach ((a) =>
                {
                  unowned string address = (string) a;
                  existing_addresses.add (address);
                });
            });
        });

      Value addresses_value = Value (typeof (HashTable));
      addresses_value.set_boxed (protocols);

      HashTable<string, Value?> details =
          new HashTable<string, Value?> (str_hash, str_equal);
      details.insert ("im-addresses", addresses_value);

      yield this.add_persona_from_details (null, this.writeable_store.type_id,
          this.writeable_store.id, details);
    }

  public async void unlink_individual (Individual individual) throws GLib.Error
    {
      /* Remove all the Personas from writeable PersonaStores
       * We have to iterate manually since using foreach() requires a sync
       * lambda function, meaning we can't yield on the remove_persona() call */
      unowned GLib.List<unowned Persona> i;
      for (i = individual.personas; i != null; i = i.next)
        {
          unowned Persona persona = (Persona) i.data;
          if (persona.store == this.writeable_store)
            yield this.writeable_store.remove_persona (persona);
        }
    }
}
