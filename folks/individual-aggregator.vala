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

  /**
   * The {@link PersonaStore} did not support writing to a property which the
   * user requested to write to, or which was necessary to write to for storing
   * linking information.
   *
   * @since UNRELEASED
   */
  PROPERTY_NOT_WRITEABLE,
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
  private unowned PersonaStore? _writeable_store = null;
  private HashSet<Backend> _backends;
  private HashTable<string, Individual> _link_map;
  private bool _linking_enabled = true;
  private bool _is_prepared = false;
  private bool _prepare_pending = false;
  private Debug _debug;
  private string _configured_writeable_store_type_id;
  private string _configured_writeable_store_id;
  private static const string _FOLKS_CONFIG_KEY =
    "/system/folks/backends/primary_store";

  /* The number of persona stores and backends we're waiting to become
   * quiescent. Once these both reach 0, we should be in a quiescent state.
   * We have to count both of them so that we can handle the case where one
   * backend becomes available, and its persona stores all become quiescent,
   * long before any other backend becomes available. In this case, we want
   * the aggregator to signal that it's reached a quiescent state only once
   * all the other backends have also become available. */
  private uint _non_quiescent_persona_store_count = 0;
  /* Same for backends. */
  private uint _non_quiescent_backend_count = 0;
  private bool _is_quiescent = false;

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
   * Whether the aggregator has reached a quiescent state. This will happen at
   * some point after {@link IndividualAggregator.prepare} has successfully
   * completed for the aggregator. An aggregator is in a quiescent state when
   * all the {@link PersonaStore}s listed by its backends have reached a
   * quiescent state.
   *
   * It's guaranteed that this property's value will only ever change after
   * {@link IndividualAggregator.is_prepared} has changed to `true`.
   *
   * @since UNRELEASED
   */
  public bool is_quiescent
    {
      get { return this._is_quiescent; }
    }

  /**
   * Our configured primary (writeable) store.
   *
   * Which one to use is decided (in order or precedence)
   * by:
   *
   * - the FOLKS_WRITEABLE_STORE env var (mostly for debugging)
   * - the GConf key set in _FOLKS_CONFIG_KEY (system set store)
   * - going with the `key-file` or `eds` store as the fall-back option
   *
   * @since 0.5.0
   */
  public PersonaStore? primary_store
    {
      get { return this._writeable_store; }
    }

  private Map<string, Individual> _individuals;
  private Map<string, Individual> _individuals_ro;

  /**
   * A map from {@link Individual.id}s to their {@link Individual}s.
   *
   * This is the canonical set of {@link Individual}s provided by this
   * IndividualAggregator.
   *
   * {@link Individual}s may be added or removed using
   * {@link IndividualAggregator.add_persona_from_details} and
   * {@link IndividualAggregator.remove_individual}, respectively.
   *
   * @since 0.5.1
   */
  public Map<string, Individual> individuals
    {
      get { return this._individuals_ro; }
      private set
        {
          this._individuals = value;
          this._individuals_ro = this._individuals.read_only_view;
        }
    }

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
   * If more information about the relationships between {@link Individual}s
   * which have been linked and unlinked is needed, consider connecting to
   * {@link IndividualAggregator.individuals_changed_detailed} instead, which is
   * emitted at the same time as this signal.
   *
   * This will not be emitted until after {@link IndividualAggregator.prepare}
   * has been called.
   *
   * @param added a list of {@link Individual}s which have been added
   * @param removed a list of {@link Individual}s which have been removed
   * @param message a string message from the backend, if any
   * @param actor the {@link Persona} who made the change, if known
   * @param reason the reason for the change
   *
   * @since 0.5.1
   */
  [Deprecated (since = "UNRELEASED",
      replacement = "IndividualAggregator.individuals_changed_detailed")]
  public signal void individuals_changed (Set<Individual> added,
      Set<Individual> removed,
      string? message,
      Persona? actor,
      GroupDetails.ChangeReason reason);

  /**
   * Emitted when one or more {@link Individual}s are added to or removed from
   * the aggregator.
   *
   * This is emitted at the same time as
   * {@link IndividualAggregator.individuals_changed}, but includes more
   * information about the relationships between {@link Individual}s which have
   * been linked and unlinked.
   *
   * Individuals which have been linked will be listed in the multi-map as
   * mappings from the old individuals to the single new individual which
   * replaces them (i.e. each of the old individuals will map to the same new
   * individual). This new individual is the one which will be specified as the
   * `replacement_individual` in the {@link Individual.removed} signal for the
   * old individuals.
   *
   * Individuals which have been unlinked will be listed in the multi-map as
   * a mapping from the unlinked individual to a set of one or more individuals
   * which replace it.
   *
   * Individuals which have been added will be listed in the multi-map as a
   * mapping from `null` to the set of added individuals. If `null` doesn't
   * map to anything, no individuals have been added to the aggregator.
   *
   * Individuals which have been removed will be listed in the multi-map as
   * mappings from the removed individual to `null`.
   *
   * This will not be emitted until after {@link IndividualAggregator.prepare}
   * has been called.
   *
   * @param added a mapping of old {@link Individual}s to new
   * {@link Individual}s for the individuals which have changed in the
   * aggregator
   *
   * @since UNRELEASED
   */
  public signal void individuals_changed_detailed (
      MultiMap<Individual?, Individual?> changes);

  /* FIXME: make this a singleton? */
  /**
   * Create a new IndividualAggregator.
   *
   * Clients should connect to the
   * {@link IndividualAggregator.individuals_changed} signal (or the
   * {@link IndividualAggregator.individuals_changed_detailed} signal), then
   * call {@link IndividualAggregator.prepare} to load the backends and start
   * aggregating individuals.
   *
   * An example of how to set up an IndividualAggregator:
   * {{{
   *   IndividualAggregator agg = new IndividualAggregator ();
   *   agg.individuals_changed_detailed.connect (individuals_changed_cb);
   *   agg.prepare ();
   * }}}
   */
  public IndividualAggregator ()
    {
      this._stores = new HashMap<string, PersonaStore> ();
      this._individuals = new HashMap<string, Individual> ();
      this._individuals_ro = this._individuals.read_only_view;
      this._link_map = new HashTable<string, Individual> (str_hash, str_equal);

      this._backends = new HashSet<Backend> ();
      this._debug = Debug.dup ();
      this._debug.print_status.connect (this._debug_print_status);

      /* Check out the configured writeable store */
      var store_config_ids = Environment.get_variable ("FOLKS_WRITEABLE_STORE");
      if (store_config_ids != null)
        {
          this._set_writeable_store (store_config_ids);
        }
      else
        {
#if ENABLE_EDS
          this._configured_writeable_store_type_id = "eds";
          this._configured_writeable_store_id = "system";
#else
          this._configured_writeable_store_type_id = "key-file";
          this._configured_writeable_store_id = "";
#endif

          try
            {
              unowned GConf.Client client = GConf.Client.get_default ();
              GConf.Value? val = client.get (this._FOLKS_CONFIG_KEY);
              if (val != null)
                this._set_writeable_store (val.get_string ());
            }
          catch (GLib.Error e)
            {
              /* We ignore errors and go with the default store */
            }
        }

      var disable_linking = Environment.get_variable ("FOLKS_DISABLE_LINKING");
      if (disable_linking != null)
        disable_linking = disable_linking.strip ().down ();
      this._linking_enabled = (disable_linking == null ||
          disable_linking == "no" || disable_linking == "0");

      this._backend_store = BackendStore.dup ();
      this._backend_store.backend_available.connect (
          this._backend_available_cb);
    }

  ~IndividualAggregator ()
    {
      this._backend_store.backend_available.disconnect (
          this._backend_available_cb);
      this._backend_store = null;

      this._debug.print_status.disconnect (this._debug_print_status);
    }

  private void _set_writeable_store (string store_config_ids)
    {
      if (store_config_ids.index_of (":") != -1)
        {
          var ids = store_config_ids.split (":", 2);
          this._configured_writeable_store_type_id = ids[0];
          this._configured_writeable_store_id = ids[1];
        }
      else
        {
          this._configured_writeable_store_type_id = store_config_ids;
          this._configured_writeable_store_id = "";
        }
    }

  private void _debug_print_status (Debug debug)
    {
      const string domain = Debug.STATUS_LOG_DOMAIN;
      const LogLevelFlags level = LogLevelFlags.LEVEL_INFO;

      debug.print_heading (domain, level, "IndividualAggregator (%p)", this);
      debug.print_key_value_pairs (domain, level,
          "Ref. count", this.ref_count.to_string (),
          "Writeable store", "%p".printf (this._writeable_store),
          "Linking enabled?", this._linking_enabled ? "yes" : "no",
          "Prepared?", this._is_prepared ? "yes" : "no",
          "Quiescent?", this._is_quiescent
              ? "yes"
              : "no (%u backends, %u persona stores left)".printf (
                  this._non_quiescent_backend_count,
                  this._non_quiescent_persona_store_count)
      );

      debug.print_line (domain, level,
          "%u Individuals:", this.individuals.size);
      debug.indent ();

      foreach (var individual in this.individuals.values)
        {
          string trust_level = null;

          switch (individual.trust_level)
            {
              case TrustLevel.NONE:
                trust_level = "none";
                break;
              case TrustLevel.PERSONAS:
                trust_level = "personas";
                break;
              default:
                assert_not_reached ();
            }

          debug.print_heading (domain, level, "Individual (%p)", individual);
          debug.print_key_value_pairs (domain, level,
              "Ref. count", individual.ref_count.to_string (),
              "ID", individual.id,
              "User?", individual.is_user ? "yes" : "no",
              "Trust level", trust_level
          );
          debug.print_line (domain, level, "%u Personas:",
              individual.personas.size);

          debug.indent ();

          foreach (var persona in individual.personas)
            {
              debug.print_heading (domain, level, "Persona (%p)", persona);
              debug.print_key_value_pairs (domain, level,
                  "Ref. count", persona.ref_count.to_string (),
                  "UID", persona.uid,
                  "IID", persona.iid,
                  "Display ID", persona.display_id,
                  "User?", persona.is_user ? "yes" : "no"
              );
            }

          debug.unindent ();
        }

      debug.unindent ();

      debug.print_line (domain, level, "%u entries in the link map:",
          this._link_map.size ());
      debug.indent ();

      var iter = HashTableIter<string, Individual> (this._link_map);
      string link_key;
      Individual individual;
      while (iter.next (out link_key, out individual) == true)
        {
          debug.print_line (domain, level,
              "%s → %p", link_key, individual);
        }

      debug.unindent ();

      debug.print_line (domain, level, "");
    }

  /**
   * Prepare the IndividualAggregator for use.
   *
   * This loads all the available backends and prepares them for use by the
   * IndividualAggregator. This should be called //after// connecting to the
   * {@link IndividualAggregator.individuals_changed} signal (or
   * {@link IndividualAggregator.individuals_changed_detailed} signal), or a
   * race condition could occur, with the signal being emitted before your code
   * has connected to them, and {@link Individual}s getting "lost" as a result.
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
          if (!this._is_prepared && !this._prepare_pending)
            {
              this._prepare_pending = true;
              yield this._backend_store.load_backends ();
              this._is_prepared = true;
              this._prepare_pending = false;
              this.notify_property ("is-prepared");
            }
        }
    }

  /**
   * Get all matches for a given {@link Individual}.
   *
   * @param matchee the individual to find matches for
   * @param min_threshold the threshold for accepting a match
   * @return a map from matched individuals to the degree with which they match
   * `matchee` (which is guaranteed to at least equal `min_threshold`);
   * if no matches could be found, an empty map is returned
   *
   * @since 0.5.1
   */
  public Map<Individual, MatchResult> get_potential_matches
      (Individual matchee, MatchResult min_threshold = MatchResult.VERY_HIGH)
    {
      HashMap<Individual, MatchResult> matches =
          new HashMap<Individual, MatchResult> ();
      Folks.PotentialMatch matchObj = new Folks.PotentialMatch ();

      foreach (var i in this._individuals.values)
        {
          if (i.id == matchee.id)
                continue;

          var result = matchObj.potential_match (i, matchee);
          if (result >= min_threshold)
            {
              matches.set (i, result);
            }
        }

      return matches;
    }

  /**
   * Get all combinations between all {@link Individual}s.
   *
   * @param min_threshold the threshold for accepting a match
   * @return a map from each individual in the aggregator to a map of the
   * other individuals in the aggregator which can be matched with that
   * individual, mapped to the degree with which they match the original
   * individual (which is guaranteed to at least equal `min_threshold`)
   *
   * @since 0.5.1
   */
  public Map<Individual, Map<Individual, MatchResult>>
      get_all_potential_matches
        (MatchResult min_threshold = MatchResult.VERY_HIGH)
    {
      HashMap<Individual, HashMap<Individual, MatchResult>> matches =
        new HashMap<Individual, HashMap<Individual, MatchResult>> ();
      var individuals = this._individuals.values.to_array ();
      Folks.PotentialMatch matchObj = new Folks.PotentialMatch ();

      for (var i = 0; i < individuals.length; i++)
        {
          var a = individuals[i];
          var matches_a = matches.get (a);
          if (matches_a == null)
            {
              matches_a = new HashMap<Individual, MatchResult> ();
              matches.set (a, matches_a);
            }

          for (var f = i + 1; f < individuals.length; f++)
            {
              var b = individuals[f];
              var matches_b = matches.get (b);
              if (matches_b == null)
                {
                  matches_b = new HashMap<Individual, MatchResult> ();
                  matches.set (b, matches_b);
                }

              var result = matchObj.potential_match (a, b);

              if (result >= min_threshold)
                {
                  matches_a.set (b, result);
                  matches_b.set (a, result);
                }
            }
        }

      return matches;
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
          backend.notify["is-quiescent"].connect (
              this._backend_is_quiescent_changed_cb);

          /* handle the stores that have already been signaled */
          foreach (var persona_store in backend.persona_stores.values)
              {
                this._backend_persona_store_added_cb (backend, persona_store);
              }
        }
    }

  private void _backend_available_cb (BackendStore backend_store,
      Backend backend)
    {
      /* Increase the number of non-quiescent backends we're waiting for.
       * If we've already reached a quiescent state, this is ignored. If we
       * haven't, this delays us reaching a quiescent state until the
       * _backend_is_quiescent_changed_cb() callback is called for this
       * backend. */
      if (backend.is_quiescent == false)
        {
          this._non_quiescent_backend_count++;
        }

      this._add_backend.begin (backend);
    }

  private void _backend_persona_store_added_cb (Backend backend,
      PersonaStore store)
    {
      var store_id = this._get_store_full_id (store.type_id, store.id);

      /* We use the configured PersonaStore as the only trusted and writeable
       * PersonaStore.
       *
       * If the type_id is `eds` we *must* know the actual store
       * (address book) we are talking about or we might end up using
       * a random store on every run.
       */
      if (store.type_id == this._configured_writeable_store_type_id)
        {
          if ((store.type_id != "eds" &&
                  this._configured_writeable_store_id == "") ||
              this._configured_writeable_store_id == store.id)
            {
              store.is_writeable = true;
              store.trust_level = PersonaStoreTrust.FULL;
              this._writeable_store = store;
              this.notify_property ("primary-store");
            }
        }

      this._stores.set (store_id, store);
      store.personas_changed.connect (this._personas_changed_cb);
      store.notify["is-writeable"].connect (this._is_writeable_changed_cb);
      store.notify["trust-level"].connect (this._trust_level_changed_cb);
      store.notify["is-quiescent"].connect (
          this._persona_store_is_quiescent_changed_cb);

      /* Increase the number of non-quiescent persona stores we're waiting for.
       * If we've already reached a quiescent state, this is ignored. If we
       * haven't, this delays us reaching a quiescent state until the
       * _persona_store_is_quiescent_changed_cb() callback is called for this
       * store. */
      if (store.is_quiescent == false)
        {
          this._non_quiescent_persona_store_count++;
        }

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
      store.notify["is-quiescent"].disconnect (
          this._persona_store_is_quiescent_changed_cb);
      store.notify["trust-level"].disconnect (this._trust_level_changed_cb);
      store.notify["is-writeable"].disconnect (this._is_writeable_changed_cb);

      /* If we were still waiting on this persona store to reach a quiescent
       * state, stop waiting. */
      if (this._is_quiescent == false && store.is_quiescent == false)
        {
          this._non_quiescent_persona_store_count--;
          this._notify_if_is_quiescent ();
        }

      /* no need to remove this store's personas from all the individuals, since
       * they'll do that themselves (and emit their own 'removed' signal if
       * necessary) */

      if (this._writeable_store == store)
        {
          this._writeable_store = null;
          this.notify_property ("primary-store");
        }
      this._stores.unset (this._get_store_full_id (store.type_id, store.id));
    }

  private string _get_store_full_id (string type_id, string id)
    {
      return type_id + ":" + id;
    }

  /* Emit the individuals-changed signal ensuring that null parameters are
   * turned into empty sets, and both sets passed to signal handlers are
   * read-only. */
  private void _emit_individuals_changed (Set<Individual>? added,
      Set<Individual>? removed,
      MultiMap<Individual?, Individual?>? changes,
      string? message = null,
      Persona? actor = null,
      GroupDetails.ChangeReason reason = GroupDetails.ChangeReason.NONE)
    {
      var _added = added;
      var _removed = removed;
      var _changes = changes;

      if ((added == null || added.size == 0) &&
          (removed == null || removed.size == 0) &&
          (changes == null || changes.size == 0))
        {
          /* Don't bother emitting it if nothing's changed */
          return;
        }
      else if (added == null)
        {
          _added = new HashSet<Individual> ();
        }
      else if (removed == null)
        {
          _removed = new HashSet<Individual> ();
        }
      else if (changes == null)
        {
          _changes = new HashMultiMap<Individual?, Individual?> ();
        }

      this.individuals_changed (_added.read_only_view, _removed.read_only_view,
          message, actor, reason);
      this.individuals_changed_detailed (_changes);
    }

  private void _connect_to_individual (Individual individual)
    {
      individual.removed.connect (this._individual_removed_cb);
      this._individuals.set (individual.id, individual);
    }

  private void _disconnect_from_individual (Individual individual)
    {
      this._individuals.unset (individual.id);
      individual.removed.disconnect (this._individual_removed_cb);
    }

  private void _add_personas (Set<Persona> added, ref Individual user,
      ref HashMultiMap<Individual?, Individual?> individuals_changes)
    {
      foreach (var persona in added)
        {
          PersonaStoreTrust trust_level = persona.store.trust_level;

          /* These are the Individuals whose Personas will be linked together
           * to form the `final_individual`.
           * Since a given Persona can only be part of one Individual, and the
           * code in Persona._set_personas() ensures that there are no duplicate
           * Personas in a given Individual, ensuring that there are no
           * duplicate Individuals in `candidate_inds` (by using a
           * HashSet) guarantees that there will be no duplicate Personas
           * in the `final_individual`. */
          HashSet<Individual> candidate_inds = new HashSet<Individual> ();

          var final_personas = new HashSet<Persona> ();
          Individual final_individual = null;

          debug ("Aggregating persona '%s' on '%s'.", persona.uid, persona.iid);

          /* If the Persona is the user, we *always* want to link it to the
           * existing this.user. */
          if (persona.is_user == true && user != null)
            {
              debug ("    Found candidate individual '%s' as user.", user.id);
              candidate_inds.add (user);
            }

          /* If we don't trust the PersonaStore at all, we can't link the
           * Persona to any existing Individual */
          if (trust_level != PersonaStoreTrust.NONE)
            {
              var candidate_ind = this._link_map.lookup (persona.iid);
              if (candidate_ind != null &&
                  candidate_ind.trust_level != TrustLevel.NONE &&
                  !candidate_inds.contains (candidate_ind))
                {
                  debug ("    Found candidate individual '%s' by IID '%s'.",
                      candidate_ind.id, persona.iid);
                  candidate_inds.add (candidate_ind);
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
                      unowned string prop_linking_value = l;
                      var candidate_ind =
                          this._link_map.lookup (prop_linking_value);

                      if (candidate_ind != null &&
                          candidate_ind.trust_level != TrustLevel.NONE &&
                          !candidate_inds.contains (candidate_ind))
                        {
                          debug ("    Found candidate individual '%s' by " +
                              "linkable property '%s' = '%s'.",
                              candidate_ind.id, prop_name, prop_linking_value);
                          candidate_inds.add (candidate_ind);
                        }
                    });
                }
            }

          /* Ensure the original persona makes it into the final individual */
          final_personas.add (persona);

          if (candidate_inds.size > 0 && this._linking_enabled == true)
            {
              /* The Persona's IID or linkable properties match one or more
               * linkable fields which are already in the link map, so we link
               * together all the Individuals we found to form a new
               * final_individual. Later, we remove the Personas from the old
               * Individuals so that the Individuals themselves are removed. */
              foreach (var individual in candidate_inds)
                {
                  final_personas.add_all (individual.personas);
                }
            }
          else if (candidate_inds.size > 0)
            {
              debug ("    Linking disabled.");
            }
          else
            {
              debug ("    Did not find any candidate individuals.");
            }

          /* Create the final linked Individual */
          final_individual = new Individual (final_personas);
          debug ("    Created new individual '%s' (%p) with personas:",
              final_individual.id, final_individual);
          foreach (var p in final_personas)
            {
              debug ("        %s (%p)", p.uid, p);
              this._add_persona_to_link_map (p, final_individual);
            }

          uint num_mappings_added = 0;

          foreach (var i in candidate_inds)
            {
              /* Transitively update the individuals_changes. We have to do this
               * in two stages as we can't modify individuals_changes while
               * iterating over it. */
              var transitive_updates = new HashSet<Individual> ();

              foreach (var k in individuals_changes.get_keys ())
                {
                  if (i in individuals_changes.get (k))
                    {
                      transitive_updates.add (k);
                    }
                }

              foreach (var k in transitive_updates)
                {
                  assert (individuals_changes.remove (k, i) == true);

                  /* If we're saying the final_individual is replacing some of
                   * these candidate individuals, we don't also want to say that
                   * it's been added (by also emitting a mapping from
                   * null → final_individual). */
                  if (k != null)
                    {
                      individuals_changes.set (k, final_individual);
                      num_mappings_added++;
                    }
                }

              /* If there were no transitive changes to make, it's because this
               * candidate individual existed before this call to
               * _add_personas(), so it's safe to say it's being replaced by
               * the final_individual. */
              if (transitive_updates.size == 0)
                {
                  individuals_changes.set (i, final_individual);
                  num_mappings_added++;
                }
            }

          /* If there were no candidate individuals or they were all freshly
           * added (i.e. mapped from null → candidate_individual), mark the
           * final_individual as added. */
          if (num_mappings_added == 0)
            {
              individuals_changes.set (null, final_individual);
            }

          /* If the final Individual is the user, set them as such. */
          if (final_individual.is_user == true)
            user = final_individual;
        }
    }

  private void _add_persona_to_link_map (Persona persona, Individual individual)
    {
      debug ("Connecting to Persona: %s (is user: %s, IID: %s)", persona.uid,
          persona.is_user ? "yes" : "no", persona.iid);
      debug ("    Mapping to Individual: %s", individual.id);

      /* Add the Persona to the link map. Its trust level will be reflected in
       * final_individual.trust_level, so other Personas won't be linked against
       * it in error if the trust level is NONE. */
      this._link_map.replace (persona.iid, individual);

      /* Only allow linking on non-IID properties of the Persona if we fully
       * trust the PersonaStore it came from. */
      if (persona.store.trust_level == PersonaStoreTrust.FULL)
        {
          debug ("    Inserting links:");

          /* Insert maps from the Persona's linkable properties to the
           * Individual. */
          foreach (unowned string prop_name in persona.linkable_properties)
            {
              debug ("        %s", prop_name);

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
                  unowned string prop_linking_value = l;

                  debug ("            %s", prop_linking_value);
                  this._link_map.replace (prop_linking_value, individual);
                });
            }
        }
    }

  /* We remove individuals as a whole from the link map, rather than iterating
   * through the link map keys generated by their personas (as in
   * _add_persona_to_link_map()) because the values of the personas' linkable
   * properties may well have changed since we added the personas to the link
   * map. If that's the case, we don't want to end up leaving stale entries in
   * the link map, since that *will* cause problems later on. */
  private void _remove_individual_from_link_map (Individual individual)
    {
      debug ("Removing Individual '%s' from the link map.", individual.id);

      var iter = HashTableIter<string, Individual> (this._link_map);
      string link_key;
      Individual link_individual;

      while (iter.next (out link_key, out link_individual) == true)
        {
          if (link_individual == individual)
            {
              debug ("    %s → %s (%p)",
                  link_key, link_individual.id, link_individual);

              iter.remove ();
            }
        }
    }

  private void _personas_changed_cb (PersonaStore store,
      Set<Persona> added,
      Set<Persona> removed,
      string? message,
      Persona? actor,
      GroupDetails.ChangeReason reason)
    {
      var removed_individuals = new HashSet<Individual> ();
      var individuals_changes = new HashMultiMap<Individual?, Individual?> ();
      var relinked_personas = new HashSet<Persona> ();
      var replaced_individuals = new HashMap<Individual, Individual> ();

      /* We store the value of this.user locally and only update it at the end
       * of the function to prevent spamming notifications of changes to the
       * property. */
      var user = this.user;

      debug ("Removing Personas:");

      foreach (var persona in removed)
        {
          debug ("    %s (is user: %s, IID: %s)", persona.uid,
              persona.is_user ? "yes" : "no", persona.iid);

          /* Find the Individual containing the Persona (if any) and mark them
           * for removal (any other Personas they have which aren't being
           * removed will be re-linked into other Individuals). */
          var ind = this._link_map.lookup (persona.iid);
          if (ind != null)
            {
              removed_individuals.add (ind);
              individuals_changes.set (ind, null);
            }

        }

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
          if (this._individuals.has_key (individual.id) == false)
            continue;

          debug ("    %s", individual.id);

          /* Build a list of Personas which need relinking. Ensure we don't
           * include any of the Personas which have just been removed. */
          foreach (var persona in individual.personas)
            {
              if (removed.contains (persona) == true ||
                  relinked_personas.contains (persona) == true)
                continue;

              relinked_personas.add (persona);
            }

          if (user == individual)
            user = null;

          this._disconnect_from_individual (individual);
          individual.personas = null;

          /* Remove the Individual's links from the link map */
          this._remove_individual_from_link_map (individual);
        }

      debug ("Adding Personas:");
      foreach (var persona in added)
        {
          debug ("    %s (is user: %s, IID: %s)", persona.uid,
              persona.is_user ? "yes" : "no", persona.iid);
        }

      if (added.size > 0)
        {
          this._add_personas (added, ref user, ref individuals_changes);
        }

      debug ("Relinking Personas:");
      foreach (var persona in relinked_personas)
        {
          debug ("    %s (is user: %s, IID: %s)", persona.uid,
              persona.is_user ? "yes" : "no", persona.iid);
        }

      this._add_personas (relinked_personas, ref user, ref individuals_changes);

      /* Notify of changes to this.user */
      this.user = user;

      /* Signal the addition of new individuals and removal of old ones to the
       * aggregator */
      if (individuals_changes.size > 0)
        {
          var added_individuals = new HashSet<Individual> ();

          /* Extract the deprecated added and removed sets from
           * individuals_changes, to be used in the individuals_changed
           * signal. */
          foreach (var old_ind in individuals_changes.get_keys ())
            {
              foreach (var new_ind in individuals_changes.get (old_ind))
                {
                  assert (old_ind != null || new_ind != null);

                  if (old_ind != null)
                    {
                      removed_individuals.add (old_ind);
                    }

                  if (new_ind != null)
                    {
                      added_individuals.add (new_ind);
                      this._connect_to_individual (new_ind);
                    }

                  if (old_ind != null && new_ind != null)
                    {
                      replaced_individuals.set (old_ind, new_ind);
                    }
                }
            }

          this._emit_individuals_changed (added_individuals,
              removed_individuals, individuals_changes);
        }

      /* Signal the replacement of various Individuals as a consequence of
       * linking. */
      debug ("Replacing Individuals due to linking:");
      var iter = replaced_individuals.map_iterator ();
      while (iter.next () == true)
        {
          iter.get_key ().replace (iter.get_value ());
        }

      /* Validate the link map. */
      if (this._debug.debug_output_enabled == true)
        {
          var iter2 = HashTableIter<string, Individual> (this._link_map);
          string link_key;
          Individual individual;

          while (iter2.next (out link_key, out individual) == true)
            {
              if (this._individuals.get (individual.id) != individual)
                {
                  warning ("Link map contains invalid mapping:\n" +
                      "    %s → %s (%p)",
                          link_key, individual.id, individual);
                  warning ("Individual %s (%p) personas:", individual.id,
                      individual);
                  foreach (var p in individual.personas)
                    {
                      warning ("    %s (%p)", p.uid, p);
                    }
                }
            }
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
      /* Only our writeable_store can be fully trusted. */
      var store = (PersonaStore) object;
      if (this._writeable_store != null &&
          store == this._writeable_store)
        assert (store.trust_level == PersonaStoreTrust.FULL);
      else
        assert (store.trust_level != PersonaStoreTrust.FULL);
    }

  private void _persona_store_is_quiescent_changed_cb (Object obj,
      ParamSpec pspec)
    {
      /* Have we reached a quiescent state yet? */
      if (this._non_quiescent_persona_store_count > 0)
        {
          this._non_quiescent_persona_store_count--;
          this._notify_if_is_quiescent ();
        }
    }

  private void _backend_is_quiescent_changed_cb (Object obj, ParamSpec pspec)
    {
      if (this._non_quiescent_backend_count > 0)
        {
          this._non_quiescent_backend_count--;
          this._notify_if_is_quiescent ();
        }
    }

  private void _notify_if_is_quiescent ()
    {
      if (this._non_quiescent_backend_count == 0 &&
          this._non_quiescent_persona_store_count == 0 &&
          this._is_quiescent == false)
        {
          this._is_quiescent = true;
          this.notify_property ("is-quiescent");
        }
    }

  private void _individual_removed_cb (Individual i, Individual? replacement)
    {
      if (this.user == i)
        this.user = null;

      /* Only signal if the individual is still in this.individuals. This allows
       * us to group removals together in, e.g., _personas_changed_cb(). */
      if (this._individuals.get (i.id) != i)
        return;

      if (replacement != null)
        {
          debug ("Individual '%s' removed (replaced by '%s')", i.id,
              replacement.id);
        }
      else
        {
          debug ("Individual '%s' removed (not replaced)", i.id);
        }

      /* If the individual has 0 personas, we've already signaled removal */
      if (i.personas.size > 0)
        {
          var changes = new HashMultiMap<Individual?, Individual?> ();
          var individuals = new HashSet<Individual> ();

          individuals.add (i);
          changes.set (i, replacement);

          this._emit_individuals_changed (null, individuals, changes);
        }

      this._disconnect_from_individual (i);
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
   *  * message - a user-readable message to pass to the persona being added
   *
   * If a {@link Persona} with the given details already exists in the store, no
   * error will be thrown and this function will return `null`.
   *
   * @param parent an optional {@link Individual} to add the new {@link Persona}
   * to. This persona will be appended to its ordered list of personas.
   * @param persona_store the {@link PersonaStore} to add the persona to
   * @param details a key-value map of details to use in creating the new
   * {@link Persona}
   * @return the new {@link Persona} or `null` if the corresponding
   * {@link Persona} already existed. If non-`null`, the new {@link Persona}
   * will also be added to a new or existing {@link Individual} as necessary.
   *
   * @since 0.3.5
   */
  public async Persona? add_persona_from_details (Individual? parent,
      PersonaStore persona_store,
      HashTable<string, Value?> details) throws IndividualAggregatorError
    {
      Persona persona = null;
      try
        {
          var details_copy = this._asv_copy (details);
          persona = yield persona_store.add_persona_from_details (details_copy);
        }
      catch (PersonaStoreError e)
        {
          if (e is PersonaStoreError.STORE_OFFLINE)
            {
              throw new IndividualAggregatorError.STORE_OFFLINE (e.message);
            }
          else
            {
              var full_id = this._get_store_full_id (persona_store.type_id,
                  persona_store.id);

              throw new IndividualAggregatorError.ADD_FAILED (
                  /* Translators: the first parameter is a store identifier
                   * and the second parameter is an error message. */
                  _("Failed to add contact for persona store ID '%s': %s"),
                  full_id, e.message);
            }
        }

      if (parent != null && persona != null)
        {
          parent.personas.add (persona);
        }

      return persona;
    }

  private HashTable<string, Value?> _asv_copy (HashTable<string, Value?> asv)
    {
      var retval = new HashTable<string, Value?> (str_hash, str_equal);

      asv.foreach ((k, v) =>
        {
          retval.insert ((string) k, v);
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
      /* Removing personas changes the persona set so we need to make a copy
       * first */
      var personas = new HashSet<Persona> ();
      foreach (var p in individual.personas)
        {
          personas.add (p);
        }

      foreach (var persona in personas)
        {
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
   * @param personas the {@link Persona}s to be linked
   * @since 0.5.1
   */
  public async void link_personas (Set<Persona> personas)
      throws IndividualAggregatorError
    {
      if (this._writeable_store == null)
        {
          throw new IndividualAggregatorError.NO_WRITEABLE_STORE (
              _("Can't link personas with no writeable store."));
        }

      /* Don't bother linking if it's just one Persona */
      if (personas.size <= 1)
        return;

      /* Disallow linking if it's disabled */
      if (this._linking_enabled == false)
        {
          debug ("Can't link Personas: linking disabled.");
          return;
        }

      /* Create a new persona in the writeable store which links together the
       * given personas */
      assert (this._writeable_store.type_id ==
          this._configured_writeable_store_type_id);

      /* `protocols_addrs_set` will be passed to the new Kf.Persona */
      var protocols_addrs_set = new HashMultiMap<string, ImFieldDetails> (
            null, null,
            (GLib.HashFunc) ImFieldDetails.hash,
            (GLib.EqualFunc) ImFieldDetails.equal);
      var web_service_addrs_set =
        new HashMultiMap<string, WebServiceFieldDetails> (
            null, null,
            (GLib.HashFunc) WebServiceFieldDetails.hash,
            (GLib.EqualFunc) WebServiceFieldDetails.equal);

      /* List of local_ids */
      var local_ids = new Gee.HashSet<string> ();

      foreach (var persona in personas)
        {
          if (persona is ImDetails)
            {
              ImDetails im_details = (ImDetails) persona;

              /* protocols_addrs_set = union (all personas' IM addresses) */
              foreach (var protocol in im_details.im_addresses.get_keys ())
                {
                  var im_addresses = im_details.im_addresses.get (protocol);

                  foreach (var im_address in im_addresses)
                    {
                      protocols_addrs_set.set (protocol, im_address);
                    }
                }
            }

          if (persona is WebServiceDetails)
            {
              WebServiceDetails ws_details = (WebServiceDetails) persona;

              /* web_service_addrs_set = union (all personas' WS addresses) */
              foreach (var web_service in
                  ws_details.web_service_addresses.get_keys ())
                {
                  var ws_addresses =
                      ws_details.web_service_addresses.get (web_service);

                  foreach (var ws_fd in ws_addresses)
                    web_service_addrs_set.set (web_service, ws_fd);
                }
            }

          if (persona is LocalIdDetails)
            {
              foreach (var id in ((LocalIdDetails) persona).local_ids)
                {
                  local_ids.add (id);
                }
            }
        }

      var details = new HashTable<string, Value?> (str_hash, str_equal);

      if (protocols_addrs_set.size > 0)
        {
          var im_addresses_value = Value (typeof (MultiMap));
          im_addresses_value.set_object (protocols_addrs_set);
          details.insert (PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES),
              im_addresses_value);
        }

      if (web_service_addrs_set.size > 0)
        {
          var web_service_addresses_value = Value (typeof (MultiMap));
          web_service_addresses_value.set_object (web_service_addrs_set);
          details.insert (PersonaStore.detail_key
              (PersonaDetail.WEB_SERVICE_ADDRESSES),
              web_service_addresses_value);
        }

      if (local_ids.size > 0)
        {
          var local_ids_value = Value (typeof (Set<string>));
          local_ids_value.set_object (local_ids);
          details.insert (
              Folks.PersonaStore.detail_key (PersonaDetail.LOCAL_IDS),
              local_ids_value);
        }

      yield this.add_persona_from_details (null,
          this._writeable_store, details);
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

      debug ("Unlinking Individual '%s', deleting Personas:", individual.id);

      /* Remove all the Personas from writeable PersonaStores.
       *
       * We have to take a copy of the Persona list before removing the
       * Personas, as _personas_changed_cb() (which is called as a result of
       * calling _writeable_store.remove_persona()) messes around with Persona
       * lists. */
      var personas = new HashSet<Persona> ();
      foreach (var p in individual.personas)
        {
          personas.add (p);
        }

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

  /**
   * Ensure that the given property is writeable for the given
   * {@link Individual}.
   *
   * This makes sure that there is at least one {@link Persona} in the
   * individual which has `property_name` in its
   * {@link Persona.writeable_properties}. If no such persona exists in the
   * individual, a new one will be created and linked to the individual. (Note
   * that due to the design of the aggregator, this will result in the previous
   * individual being removed and replaced by a new one with the new persona;
   * listen to the {@link Individual.removed} signal to see the replacement.)
   *
   * It may not be possible to create a new persona which has the given property
   * as writeable. In that case, a
   * {@link IndividualAggregatorError.NO_WRITEABLE_STORE} or
   * {@link IndividualAggregatorError.PROPERTY_NOT_WRITEABLE} error will be
   * thrown.
   *
   * @param individual the individual for which `property_name` should be
   * writeable
   * @param property_name the name of the property which needs to be writeable
   * (this should be in lower case using hyphens, e.g. “web-service-addresses”)
   * @return a persona (new or existing) which has the given property as
   * writeable
   *
   * @since UNRELEASED
   */
  public async Persona ensure_individual_property_writeable (
      Individual individual, string property_name)
      throws IndividualAggregatorError
    {
      debug ("ensure_individual_property_writeable: %s, %s",
          individual.id, property_name);

      /* See if the individual already contains the property we want. */
      foreach (var p1 in individual.personas)
        {
          if (property_name in p1.writeable_properties)
            {
              debug ("    Returning existing persona: %s", p1.uid);
              return p1;
            }
        }

      /* Otherwise, create a new persona in the writeable store. If the
       * writeable store doesn't exist or doesn't support writing to the given
       * property, we try the other persona stores. */
      var details = new HashTable<string, Value?> (str_hash, str_equal);
      Persona? new_persona = null;

      if (this._writeable_store != null &&
          property_name in this._writeable_store.always_writeable_properties)
        {
          try
            {
              debug ("    Using writeable store");
              new_persona = yield this.add_persona_from_details (null,
                  this._writeable_store, details);
            }
          catch (IndividualAggregatorError e1)
            {
              /* Ignore it */
              new_persona = null;
            }
        }

      if (new_persona == null)
        {
          foreach (var s in this._stores.values)
            {
              if (s == this._writeable_store ||
                  !(property_name in s.always_writeable_properties))
                {
                  /* Skip the store we've just tried */
                  continue;
                }

              try
                {
                  debug ("    Using store %s", s.id);
                  new_persona = yield this.add_persona_from_details (null, s,
                      details);
                }
              catch (IndividualAggregatorError e2)
                {
                  /* Ignore it */
                  new_persona = null;
                  continue;
                }
            }
        }

      /* Throw an error if we haven't managed to find a suitable store */
      if (new_persona == null && this._writeable_store == null)
        {
          throw new IndividualAggregatorError.NO_WRITEABLE_STORE (
              _("Can't add personas with no writeable store."));
        }
      else if (new_persona == null)
        {
          throw new IndividualAggregatorError.PROPERTY_NOT_WRITEABLE (
              _("Can't write to requested property (“%s”) of the writeable store."),
              property_name);
        }

      /* Link the persona to the existing individual */
      var linking_personas = new HashSet<Persona> ();
      linking_personas.add (new_persona);

      foreach (var p2 in individual.personas)
        {
          linking_personas.add (p2);
        }

      debug ("    Linking personas to ensure %s property is writeable.",
          property_name);
      yield this.link_personas (linking_personas);

      return new_persona;
    }
}
