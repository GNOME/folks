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
   *
   * @since 0.1.13
   */
  NO_WRITEABLE_STORE,

  /**
   * The {@link PersonaStore} was offline (ie, this is a temporary failure).
   *
   * @since 0.3.0
   */
  STORE_OFFLINE,
}

/**
 * Stores {@link Individual}s which have been created through
 * aggregation of all the {@link Persona}s provided by the various
 * {@link Backend}s.
 *
 * This is the main interface for client applications.
 */
public class Folks.IndividualAggregator : Object
{
  private BackendStore _backend_store;
  private HashMap<string, PersonaStore> _stores;
  private unowned PersonaStore _writeable_store;
  private HashSet<Backend> _backends;
  private HashTable<string, Individual> _link_map;
  private bool _linking_enabled = true;
  private bool _is_prepared = false;

  /**
   * Whether {@link IndividualAggregator.prepare} has successfully completed for
   * this aggregator.
   *
   * @since 0.3.0
   */
  public bool is_prepared
    {
      get { return this._is_prepared; }
    }

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
   * The {@link Individual} representing the user.
   *
   * If it exists, this holds the {@link Individual} who is the user: the
   * {@link Individual} containing the {@link Persona}s who are the owners of
   * the accounts for their respective backends.
   *
   * @since 0.3.0
   */
  public Individual user { get; private set; }

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
      Groupable.ChangeReason reason);

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
      this._stores = new HashMap<string, PersonaStore> ();
      this.individuals = new HashTable<string, Individual> (str_hash,
          str_equal);
      this._link_map = new HashTable<string, Individual> (str_hash, str_equal);

      this._backends = new HashSet<Backend> ();

      var disable_linking = Environment.get_variable ("FOLKS_DISABLE_LINKING");
      if (disable_linking != null)
        disable_linking = disable_linking.strip ().down ();
      this._linking_enabled = (disable_linking == null ||
          disable_linking == "no" || disable_linking == "0");

      this._backend_store = BackendStore.dup ();
      this._backend_store.backend_available.connect (
          this._backend_available_cb);
    }

  /**
   * Prepare the IndividualAggregator for use.
   *
   * This loads all the available backends and prepares them for use by the
   * IndividualAggregator. This should be called //after// connecting to the
   * {@link IndividualAggregator.individuals_changed} signal, or a race
   * condition could occur, with the signal being emitted before your code has
   * connected to them, and {@link Individual}s getting "lost" as a result.
   *
   * This function is guaranteed to be idempotent (since version 0.3.0).
   *
   * @since 0.1.11
   */
  public async void prepare () throws GLib.Error
    {
      /* Once this async function returns, all the {@link Backend}s will have
       * been prepared (though no {@link PersonaStore}s are guaranteed to be
       * available yet). This last guarantee is new as of version 0.2.0. */

      lock (this._is_prepared)
        {
          if (!this._is_prepared)
            {
              yield this._backend_store.load_backends ();
              this._is_prepared = true;
              this.notify_property ("is-prepared");
            }
        }
    }

  private async void _add_backend (Backend backend)
    {
      if (!this._backends.contains (backend))
        {
          this._backends.add (backend);

          backend.persona_store_added.connect (
              this._backend_persona_store_added_cb);
          backend.persona_store_removed.connect (
              this._backend_persona_store_removed_cb);

          /* handle the stores that have already been signaled */
          backend.persona_stores.foreach ((k, v) =>
              {
                this._backend_persona_store_added_cb (backend,
                  (PersonaStore) v);
              });
        }
    }

  private void _backend_available_cb (BackendStore backend_store,
      Backend backend)
    {
      this._add_backend.begin (backend);
    }

  private void _backend_persona_store_added_cb (Backend backend,
      PersonaStore store)
    {
      var store_id = this._get_store_full_id (store.type_id, store.id);

      /* FIXME: We hardcode the key-file backend's singleton PersonaStore as the
       * only trusted and writeable PersonaStore for now. */
      if (store.type_id == "key-file")
        {
          store.is_writeable = true;
          store.trust_level = PersonaStoreTrust.FULL;
          this._writeable_store = store;
        }

      this._stores.set (store_id, store);
      store.personas_changed.connect (this._personas_changed_cb);
      store.notify["is-writeable"].connect (this._is_writeable_changed_cb);
      store.notify["trust-level"].connect (this._trust_level_changed_cb);

      store.prepare.begin ((obj, result) =>
        {
          try
            {
              store.prepare.end (result);
            }
          catch (GLib.Error e)
            {
              /* Translators: the first parameter is a persona store identifier
               * and the second is an error message. */
              warning (_("Error preparing persona store '%s': %s"), store_id,
                  e.message);
            }
        });
    }

  private void _backend_persona_store_removed_cb (Backend backend,
      PersonaStore store)
    {
      store.personas_changed.disconnect (this._personas_changed_cb);
      store.notify["trust-level"].disconnect (this._trust_level_changed_cb);
      store.notify["is-writeable"].disconnect (this._is_writeable_changed_cb);

      /* no need to remove this store's personas from all the individuals, since
       * they'll do that themselves (and emit their own 'removed' signal if
       * necessary) */

      if (this._writeable_store == store)
        this._writeable_store = null;
      this._stores.unset (this._get_store_full_id (store.type_id, store.id));
    }

  private string _get_store_full_id (string type_id, string id)
    {
      return type_id + ":" + id;
    }

  private void _add_personas (GLib.List<Persona> added,
      ref GLib.List<Individual> added_individuals,
      ref HashMap<Individual, Individual> replaced_individuals,
      ref Individual user)
    {
      /* Set of individuals which have been added as a result of the new
       * personas. These will be returned in added_individuals, but have to be
       * cached first so that we can ensure that we don't return any given
       * individual in both added_individuals _and_ replaced_individuals. This
       * can happen in the case that several of the added personas are linked
       * together to form one final individual. In that case, a succession of
       * newly linked individuals will be produced (one for each iteration of
       * the loop over the added personas); only the *last one* of which should
       * make its way into added_individuals. The rest should not even make
       * their way into replaced_individuals, as they've existed only within the
       * confines of this function call. */
      HashSet<Individual> almost_added_individuals = new HashSet<Individual> ();

      foreach (var persona in added)
        {
          PersonaStoreTrust trust_level = persona.store.trust_level;

          /* These are the Individuals whose Personas will be linked together
           * to form the `final_individual`. We keep a list of the Individuals
           * for fast iteration, but also keep a set to ensure that we don't
           * get duplicate Individuals in the list.
           * Since a given Persona can only be part of one Individual, and the
           * code in Persona._set_personas() ensures that there are no duplicate
           * Personas in a given Individual, ensuring that there are no
           * duplicate Individuals in `candidate_inds` guarantees that there
           * will be no duplicate Personas in the `final_individual`. */
          GLib.List<Individual> candidate_inds = null;
          HashSet<Individual> candidate_ind_set = new HashSet<Individual> ();

          GLib.List<Persona> final_personas = new GLib.List<Persona> ();
          Individual final_individual = null;

          debug ("Aggregating persona '%s' on '%s'.", persona.uid, persona.iid);

          /* If the Persona is the user, we *always* want to link it to the
           * existing this.user. */
          if (persona.is_user == true && user != null)
            {
              debug ("    Found candidate individual '%s' as user.", user.id);
              candidate_inds.prepend (user);
              candidate_ind_set.add (user);
            }

          /* If we don't trust the PersonaStore at all, we can't link the
           * Persona to any existing Individual */
          if (trust_level != PersonaStoreTrust.NONE)
            {
              var candidate_ind = this._link_map.lookup (persona.iid);
              if (candidate_ind != null &&
                  candidate_ind.trust_level != TrustLevel.NONE)
                {
                  debug ("    Found candidate individual '%s' by IID '%s'.",
                      candidate_ind.id, persona.iid);
                  candidate_inds.prepend (candidate_ind);
                  candidate_ind_set.add (candidate_ind);
                }
            }

          if (persona.store.trust_level == PersonaStoreTrust.FULL)
            {
              /* If we trust the PersonaStore the Persona came from, we can
               * attempt to link based on its linkable properties. */
              foreach (unowned string foo in persona.linkable_properties)
                {
                  /* FIXME: If we just use string prop_name directly in the
                   * foreach, Vala doesn't copy it into the closure data, and
                   * prop_name ends up as NULL. bgo#628336 */
                  unowned string prop_name = foo;

                  /* FIXME: can't be var because of bgo#638208 */
                  unowned ObjectClass pclass = persona.get_class ();
                  if (pclass.find_property (prop_name) == null)
                    {
                      warning (
                          /* Translators: the parameter is a property name. */
                          _("Unknown property '%s' in linkable property list."),
                          prop_name);
                      continue;
                    }

                  persona.linkable_property_to_links (prop_name, (l) =>
                    {
                      var prop_linking_value = (string) l;
                      var candidate_ind =
                          this._link_map.lookup (prop_linking_value);

                      if (candidate_ind != null &&
                          candidate_ind.trust_level != TrustLevel.NONE &&
                          !candidate_ind_set.contains (candidate_ind))
                        {
                          debug ("    Found candidate individual '%s' by " +
                              "linkable property '%s' = '%s'.",
                              candidate_ind.id, prop_name, prop_linking_value);
                          candidate_inds.prepend (candidate_ind);
                          candidate_ind_set.add (candidate_ind);
                        }
                    });
                }
            }

          /* Ensure the original persona makes it into the final persona */
          final_personas.prepend (persona);

          if (candidate_inds != null && this._linking_enabled == true)
            {
              /* The Persona's IID or linkable properties match one or more
               * linkable fields which are already in the link map, so we link
               * together all the Individuals we found to form a new
               * final_individual. Later, we remove the Personas from the old
               * Individuals so that the Individuals themselves are removed. */
              candidate_inds.foreach ((i) =>
                {
                  var individual = (Individual) i;

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
          else if (candidate_inds != null)
            {
              debug ("    Linking disabled.");
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
              var final_persona = (Persona) i;

              debug ("        %s (is user: %s, IID: %s)", final_persona.uid,
                  final_persona.is_user ? "yes" : "no", final_persona.iid);

              /* Add the Persona to the link map. Its trust level will be
               * reflected in final_individual.trust_level, so other Personas
               * won't be linked against it in error if the trust level is
               * NONE. */
              this._link_map.replace (final_persona.iid, final_individual);

              /* Only allow linking on non-IID properties of the Persona if we
               * fully trust the PersonaStore it came from. */
              if (final_persona.store.trust_level == PersonaStoreTrust.FULL)
                {
                  debug ("        Inserting links:");

                  /* Insert maps from the Persona's linkable properties to the
                   * Individual. */
                  foreach (unowned string prop_name in
                      final_persona.linkable_properties)
                    {
                      /* FIXME: can't be var because of bgo#638208 */
                      unowned ObjectClass pclass = final_persona.get_class ();
                      if (pclass.find_property (prop_name) == null)
                        {
                          warning (
                              /* Translators: the parameter is a property
                               * name. */
                              _("Unknown property '%s' in linkable property list."),
                              prop_name);
                          continue;
                        }

                      final_persona.linkable_property_to_links (prop_name,
                          (l) =>
                        {
                          string prop_linking_value = (string) l;

                          debug ("            %s", prop_linking_value);
                          this._link_map.replace (prop_linking_value,
                              final_individual);
                        });
                    }
                }
            });

          /* Remove the old Individuals. This has to be done here, as we need
           * the final_individual. */
          foreach (var i in candidate_inds)
            {
              /* If the replaced individual was marked to be added to the
               * aggregator, unmark it. */
              if (almost_added_individuals.contains (i) == true)
                almost_added_individuals.remove (i);
              else
                replaced_individuals.set (i, final_individual);
            }

          /* If the final Individual is the user, set them as such. */
          if (final_individual.is_user == true)
            user = final_individual;

          /* Mark the final individual for addition later */
          almost_added_individuals.add (final_individual);
        }

      /* Add the set of final individuals which weren't later replaced to the
       * aggregator. */
      foreach (var i in almost_added_individuals)
        {
          /* Add the new Individual to the aggregator */
          i.removed.connect (this._individual_removed_cb);
          added_individuals.prepend (i);
          this.individuals.insert (i.id, i);
        }
    }

  private void _remove_persona_from_link_map (Persona persona)
    {
      this._link_map.remove (persona.iid);

      if (persona.store.trust_level == PersonaStoreTrust.FULL)
        {
          debug ("    Removing links to %s:", persona.uid);

          /* Remove maps from the Persona's linkable properties to
           * Individuals. Add the Individuals to a list of Individuals to be
           * removed. */
          foreach (string prop_name in persona.linkable_properties)
            {
              /* FIXME: can't be var because of bgo#638208 */
              unowned ObjectClass pclass = persona.get_class ();
              if (pclass.find_property (prop_name) == null)
                {
                  warning (
                      /* Translators: the parameter is a property name. */
                      _("Unknown property '%s' in linkable property list."),
                      prop_name);
                  continue;
                }

              persona.linkable_property_to_links (prop_name, (l) =>
                {
                  string prop_linking_value = (string) l;

                  debug ("        %s", prop_linking_value);
                  this._link_map.remove (prop_linking_value);
                });
            }
        }
    }

  private void _personas_changed_cb (PersonaStore store,
      GLib.List<Persona>? added,
      GLib.List<Persona>? removed,
      string? message,
      Persona? actor,
      Groupable.ChangeReason reason)
    {
      var added_individuals = new GLib.List<Individual> ();
      GLib.List<Individual> removed_individuals = null;
      var replaced_individuals = new HashMap<Individual, Individual> ();
      GLib.List<Persona> relinked_personas = null;
      var relinked_personas_set = new HashSet<Persona> (direct_hash,
          direct_equal);
      var removed_personas = new HashSet<Persona> (direct_hash, direct_equal);

      /* We store the value of this.user locally and only update it at the end
       * of the function to prevent spamming notifications of changes to the
       * property. */
      var user = this.user;

      if (added != null)
        {
          this._add_personas (added, ref added_individuals,
              ref replaced_individuals, ref user);
        }

      debug ("Removing Personas:");

      removed.foreach ((p) =>
        {
          var persona = (Persona) p;

          debug ("    %s (is user: %s, IID: %s)", persona.uid,
              persona.is_user ? "yes" : "no", persona.iid);

          /* Build a hash table of the removed Personas so that we can quickly
           * eliminate them from the list of Personas to relink, below. */
          removed_personas.add (persona);

          /* Find the Individual containing the Persona (if any) and mark them
           * for removal (any other Personas they have which aren't being
           * removed will be re-linked into other Individuals). */
          var ind = this._link_map.lookup (persona.iid);
          if (ind != null)
            removed_individuals.prepend (ind);

          /* Remove the Persona's links from the link map */
          this._remove_persona_from_link_map (persona);
        });

      /* Remove the Individuals which were pointed to by the linkable properties
       * of the removed Personas. We can then re-link the other Personas in
       * those Individuals, since their links may have changed.
       * Note that we remove the Individual from this.individuals, meaning that
       * _individual_removed_cb() ignores this Individual. This allows us to
       * group together the IndividualAggregator.individuals_changed signals
       * for all the removed Individuals. */
      debug ("Removing Individuals due to removed links:");
      foreach (var individual in removed_individuals)
        {
          /* Ensure we don't remove the same Individual twice */
          if (this.individuals.lookup (individual.id) == null)
            continue;

          debug ("    %s", individual.id);

          /* Build a list of Personas which need relinking. Ensure we don't
           * include any of the Personas which have just been removed. */
          foreach (var persona in individual.personas)
            {
              if (removed_personas.contains (persona) == true ||
                  relinked_personas_set.contains (persona) == true)
                continue;

              relinked_personas.prepend (persona);
              relinked_personas_set.add (persona);

              /* Remove links to the Persona */
              this._remove_persona_from_link_map (persona);
            }

          if (user == individual)
            user = null;

          this.individuals.remove (individual.id);
          individual.personas = null;
        }

      debug ("Relinking Personas:");
      foreach (var persona in relinked_personas)
        {
          debug ("    %s (is user: %s, IID: %s)", persona.uid,
              persona.is_user ? "yes" : "no", persona.iid);
        }

      this._add_personas (relinked_personas, ref added_individuals,
          ref replaced_individuals, ref user);

      /* Signal the removal of the replaced_individuals at the same time as the
       * removed_individuals. (The only difference between replaced individuals
       * and removed ones is that replaced individuals specify a replacement
       * when they emit their Individual:removed signal. */
      if (replaced_individuals != null)
        {
          MapIterator<Individual, Individual> iter =
              replaced_individuals.map_iterator ();
          while (iter.next () == true)
            removed_individuals.prepend (iter.get_key ());
        }

      /* Notify of changes to this.user */
      this.user = user;

      /* Signal the addition of new individuals and removal of old ones to the
       * aggregator */
      if (added_individuals != null || removed_individuals != null)
        {
          this.individuals_changed (added_individuals, removed_individuals,
              null, null, 0);
        }

      /* Signal the replacement of various Individuals as a consequence of
       * linking. */
      debug ("Replacing Individuals due to linking:");
      var iter = replaced_individuals.map_iterator ();
      while (iter.next () == true)
        {
          iter.get_key ().replace (iter.get_value ());
        }
    }

  private void _is_writeable_changed_cb (Object object, ParamSpec pspec)
    {
      /* Ensure that we only have one writeable PersonaStore */
      var store = (PersonaStore) object;
      assert ((store.is_writeable == true && store == this._writeable_store) ||
          (store.is_writeable == false && store != this._writeable_store));
    }

  private void _trust_level_changed_cb (Object object, ParamSpec pspec)
    {
      /* FIXME: For the moment, assert that only the key-file backend's
       * singleton PersonaStore is trusted. */
      var store = (PersonaStore) object;
      if (store.type_id == "key-file")
        assert (store.trust_level == PersonaStoreTrust.FULL);
      else
        assert (store.trust_level != PersonaStoreTrust.FULL);
    }

  private void _individual_removed_cb (Individual i, Individual? replacement)
    {
      /* Only signal if the individual is still in this.individuals. This allows
       * us to group removals together in, e.g., _personas_changed_cb(). */
      if (this.individuals.lookup (i.id) == null)
        return;

      if (this.user == i)
        this.user = null;

      var i_list = new GLib.List<Individual> ();
      i_list.append (i);

      if (replacement != null)
        {
          debug ("Individual '%s' removed (replaced by '%s')", i.id,
              replacement.id);
        }
      else
        {
          debug ("Individual '%s' removed (not replaced)", i.id);
        }

      this.individuals_changed (null, i_list, null, null, 0);
      this.individuals.remove (i.id);
    }

  /**
   * Add a new persona in the given {@link PersonaStore} based on the `details`
   * provided.
   *
   * If the target store is offline, this function will throw
   * {@link IndividualAggregatorError.STORE_OFFLINE}. It's the responsibility of
   * the caller to cache details and re-try this function if it wishes to make
   * offline adds work.
   *
   * The details hash is a backend-specific mapping of key, value strings.
   * Common keys include:
   *
   *  * contact - service-specific contact ID
   *
   * If a {@link Persona} with the given details already exists in the store, no
   * error will be thrown and this function will return `null`.
   *
   * @param parent an optional {@link Individual} to add the new {@link Persona}
   * to. This persona will be appended to its ordered list of personas.
   * @param persona_store_type the {@link PersonaStore.type_id} of the
   * {@link PersonaStore} to use
   * @param persona_store_id the {@link PersonaStore.id} of the
   * {@link PersonaStore} to use
   * @param details a key-value map of details to use in creating the new
   * {@link Persona}
   * @return the new {@link Persona} or `null` if the corresponding
   * {@link Persona} already existed. If non-`null`, the new {@link Persona}
   * will also be added to a new or existing {@link Individual} as necessary.
   */
  public async Persona? add_persona_from_details (Individual? parent,
      string persona_store_type,
      string persona_store_id,
      HashTable<string, Value?> details) throws IndividualAggregatorError
    {
      var full_id = this._get_store_full_id (persona_store_type,
          persona_store_id);
      var store = this._stores[full_id];

      if (store == null)
        {
          throw new IndividualAggregatorError.STORE_NOT_FOUND (
              /* Translators: the parameters are store identifiers. */
              _("No store known for type ID '%s' and ID '%s'."),
              persona_store_type, persona_store_id);
        }

      Persona persona = null;
      try
        {
          var details_copy = _asv_copy (details);
          persona = yield store.add_persona_from_details (details_copy);
        }
      catch (PersonaStoreError e)
        {
          if (e is PersonaStoreError.STORE_OFFLINE)
            {
              throw new IndividualAggregatorError.STORE_OFFLINE (e.message);
            }
          else
            {
              throw new IndividualAggregatorError.ADD_FAILED (
                  /* Translators: the first two parameters are store identifiers
                   * and the third parameter is an error message. */
                  _("Failed to add contact for store type '%s', ID '%s': %s"),
                  persona_store_type, persona_store_id, e.message);
            }
        }

      if (parent != null && persona != null)
        {
          var personas = parent.personas.copy ();

          personas.append (persona);
          parent.personas = personas;
        }

      return persona;
    }

  private HashTable<string, Value?> _asv_copy (HashTable<string, Value?> asv)
    {
      var retval = new HashTable<string, Value?> (str_hash, str_equal);

      asv.foreach ((k, v) =>
        {
#if VALA_0_12
          retval.insert ((string) k, v);
#else
          retval.insert ((string) k, (Value?) v);
#endif
        });

      return retval;
    }

  /**
   * Completely remove the individual and all of its personas from their
   * backing stores.
   *
   * @param individual the {@link Individual} to remove
   * @since 0.1.11
   */
  public async void remove_individual (Individual individual) throws GLib.Error
    {
      /* We have to iterate manually since using foreach() requires a sync
       * lambda function, meaning we can't yield on the remove_persona() call */
      unowned GLib.List<unowned Persona> i;
      for (i = individual.personas; i != null; i = i.next)
        {
          var persona = (Persona) i.data;
          yield persona.store.remove_persona (persona);
        }
    }

  /**
   * Completely remove the persona from its backing store.
   *
   * This will leave other personas in the same individual alone.
   *
   * @param persona the {@link Persona} to remove
   * @since 0.1.11
   */
  public async void remove_persona (Persona persona) throws GLib.Error
    {
      yield persona.store.remove_persona (persona);
    }

  /**
   * Link the given {@link Persona}s together.
   *
   * Create links between the given {@link Persona}s so that they form a single
   * {@link Individual}. The new {@link Individual} will be returned via the
   * {@link IndividualAggregator.individuals_changed} signal.
   *
   * Removal of the {@link Individual}s which the {@link Persona}s were in
   * before is signalled by {@link IndividualAggregator.individuals_changed} and
   * {@link Individual.removed}.
   *
   * @param personas_in the {@link Persona}s to be linked
   * @since 0.1.13
   */
  public async void link_personas (void *personas_in)
      throws IndividualAggregatorError
    {
      /* FIXME: personas_in should be GLib.List<Persona>, but Vala won't allow
       * it */
      unowned GLib.List<Persona> personas = (GLib.List<Persona>) personas_in;

      if (this._writeable_store == null)
        {
          throw new IndividualAggregatorError.NO_WRITEABLE_STORE (
              _("Can't link personas with no writeable store."));
        }

      /* Don't bother linking if it's just one Persona */
      if (personas.next == null)
        return;

      /* Disallow linking if it's disabled */
      if (this._linking_enabled == false)
        {
          debug ("Can't link Personas: linking disabled.");
          return;
        }

      /* Create a new persona in the writeable store which links together the
       * given personas */
      /* FIXME: We hardcode this to use the key-file backend for now */
      assert (this._writeable_store.type_id == "key-file");

      /* `protocols_addrs_list` will be passed to the new Kf.Persona, whereas
       * `protocols_addrs_set` is used to ensure we don't get duplicate IM
       * addresses in the ordered set of addresses for each protocol in
       * `protocols_addrs_list`. It's temporary. */
      var protocols_addrs_list =
          new HashTable<string, GenericArray<string>> (str_hash, str_equal);
      var protocols_addrs_set =
          new HashTable<string, HashSet<string>> (str_hash, str_equal);

      foreach (var persona in personas)
        {
          if (!(persona is IMable))
            continue;

          ((IMable) persona).im_addresses.foreach ((k, v) =>
            {
              unowned string protocol = (string) k;
              unowned GenericArray<string> addresses = (GenericArray<string>) v;

              var address_list = protocols_addrs_list.lookup (protocol);
              var address_set = protocols_addrs_set.lookup (protocol);

              if (address_list == null || address_set == null)
                {
                  address_list = new GenericArray<string> ();
                  address_set = new HashSet<string> ();

                  protocols_addrs_list.insert (protocol, address_list);
                  protocols_addrs_set.insert (protocol, address_set);
                }

              addresses.foreach ((a) =>
                {
                  unowned string address = (string) a;

                  /* Only add the IM address to the ordered set if it isn't
                   * already a member. */
                  if (!address_set.contains (address))
                    {
                      address_list.add (address);
                      address_set.add (address);
                    }
                });
            });
        }

      var addresses_value = Value (typeof (HashTable));
      addresses_value.set_boxed (protocols_addrs_list);

      var details = new HashTable<string, Value?> (str_hash, str_equal);
      details.insert ("im-addresses", addresses_value);

      yield this.add_persona_from_details (null, this._writeable_store.type_id,
          this._writeable_store.id, details);
    }

  /**
   * Unlinks the given {@link Individual} into its constituent {@link Persona}s.
   *
   * This completely unlinks the given {@link Individual}, destroying all of
   * its writeable {@link Persona}s.
   *
   * The {@link Individual}'s removal is signalled by
   * {@link IndividualAggregator.individuals_changed} and
   * {@link Individual.removed}.
   *
   * The {@link Persona}s comprising the {@link Individual} will be re-linked
   * into one or more new {@link Individual}s, depending on how much linking
   * data remains (typically only implicit links remain). The addition of these
   * new {@link Individual}s will be signalled by
   * {@link IndividualAggregator.individuals_changed}.
   *
   * @param individual the {@link Individual} to unlink
   * @since 0.1.13
   */
  public async void unlink_individual (Individual individual) throws GLib.Error
    {
      if (this._linking_enabled == false)
        {
          debug ("Can't unlink Individual '%s': linking disabled.",
              individual.id);
          return;
        }

      /* Remove all the Personas from writeable PersonaStores
       * We have to iterate manually since using foreach() requires a sync
       * lambda function, meaning we can't yield on the remove_persona() call */
      debug ("Unlinking Individual '%s', deleting Personas:", individual.id);

      /* We have to take a copy of the Persona list before removing the
       * Personas, as _personas_changed_cb() (which is called as a result of
       * calling _writeable_store.remove_persona()) messes around with Persona
       * lists. */
      var personas = individual.personas.copy ();
      foreach (var p in personas)
        p.ref ();

      foreach (var persona in personas)
        {
          if (persona.store == this._writeable_store)
            {
              debug ("    %s (is user: %s, IID: %s)", persona.uid,
                  persona.is_user ? "yes" : "no", persona.iid);
              yield this._writeable_store.remove_persona (persona);
            }
        }
    }
}
