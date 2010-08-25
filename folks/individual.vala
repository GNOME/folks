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
using Folks;

/**
 * Trust level for an {@link Individual} for use in the UI.
 *
 * @since 0.1.16
 */
public enum Folks.TrustLevel
{
  /**
   * The {@link Individual}'s {@link Persona}s aren't trusted at all.
   *
   * This is the trust level for an {@link Individual} which contains one or
   * more {@link Persona}s which cannot be guaranteed to be the same
   * {@link Persona}s as were originally linked together.
   *
   * For example, an {@link Individual} containing a link-local XMPP
   * {@link Persona} would have this trust level, since someone else could
   * easily spoof the link-local XMPP {@link Persona}'s identity.
   *
   * @since 0.1.16
   */
  NONE,

  /**
   * The {@link Individual}'s {@link Persona}s are trusted.
   *
   * This trust level is for {@link Individual}s where it can be guaranteed
   * that all the {@link Persona}s are the same ones as when they were
   * originally linked together.
   *
   * Note that this doesn't guarantee that the user who behind each
   * {@link Persona} is who they claim to be.
   *
   * @since 0.1.16
   */
  PERSONAS
}

/**
 * A physical person, aggregated from the various {@link Persona}s the person
 * might have, such as their different IM addresses or vCard entries.
 */
public class Folks.Individual : Object,
    Alias,
    Avatar,
    Favourite,
    Groups,
    Presence
{
  private bool _is_favourite;
  private string _alias;
  private HashTable<string, bool> _groups;
  /* These two data structures should store exactly the same set of Personas:
   * the Personas contained in this Individual. The HashSet is used for fast
   * lookups, whereas the List is used for iteration.
   * The Individual's references to its Personas are kept by the HashSet;
   * since the List contains the same set of Personas, it doesn't need an
   * extra reference (and due to bgo#624249, this is a good thing). */
  private GLib.List<unowned Persona> _persona_list;
  private HashSet<Persona> _persona_set;
  /* Mapping from PersonaStore -> number of Personas from that store contained
   * in this Individual. There shouldn't be any entries with a number < 1.
   * This is used for working out when to disconnect from store signals. */
  private HashMap<PersonaStore, uint> stores;

  /**
   * The trust level of the Individual.
   *
   * This specifies how far the Individual can be trusted to be who it claims
   * to be. See the descriptions for the elements of {@link TrustLevel}.
   *
   * Clients should ''not'' allow linking of Individuals who have a trust level
   * of {@link TrustLevel.NONE}.
   *
   * @since 0.1.16
   */
  public TrustLevel trust_level { get; private set; }

  /**
   * {@inheritDoc}
   */
  public File avatar { get; private set; }

  /**
   * {@inheritDoc}
   */
  public Folks.PresenceType presence_type { get; private set; }

  /**
   * {@inheritDoc}
   */
  public string presence_message { get; private set; }

  /**
   * A unique identifier for the Individual.
   *
   * This uniquely identifies the Individual, and persists across
   * {@link IndividualAggregator} instances.
   *
   * FIXME: Will this.id actually be the persistent ID for storage?
   */
  public string id { get; private set; }

  /**
   * Emitted when the last of the Individual's {@link Persona}s has been
   * removed.
   *
   * At this point, the Individual is invalid, so any client referencing it
   * should unreference it and remove it from their UI.
   *
   * @param replacement_individual the individual which has replaced this one
   * due to linking, or `null` if this individual was removed for another reason
   */
  public signal void removed (Individual? replacement_individual);

  /**
   * {@inheritDoc}
   */
  public string alias
    {
      get { return this._alias; }

      set
        {
          if (this._alias == value)
            return;

          this._alias = value;
          this._persona_list.foreach ((p) =>
            {
              if (p is Alias && ((Persona) p).store.is_writeable == true)
                ((Alias) p).alias = value;
            });
        }
    }

  /**
   * Whether this Individual is a user-defined favourite.
   *
   * This property is `true` if any of this Individual's {@link Persona}s are
   * favourites).
   */
  public bool is_favourite
    {
      get { return this._is_favourite; }

      set
        {
          if (this._is_favourite == value)
            return;

          this._is_favourite = value;
          this._persona_list.foreach ((p) =>
            {
              if (p is Favourite && ((Persona) p).store.is_writeable == true)
                ((Favourite) p).is_favourite = value;
            });
        }
    }

  /**
   * {@inheritDoc}
   */
  public HashTable<string, bool> groups
    {
      get { return this._groups; }

      set
        {
          this._persona_list.foreach ((p) =>
            {
              if (p is Groups && ((Persona) p).store.is_writeable == true)
                ((Groups) p).groups = value;
            });
        }
    }

  /**
   * The set of {@link Persona}s encapsulated by this Individual.
   *
   * Changing the set of personas may cause updates to the aggregated properties
   * provided by the Individual, resulting in property notifications for them.
   *
   * Changing the set of personas will not cause permanent linking/unlinking of
   * the added/removed personas to/from this Individual. To do that, call
   * {@link IndividualAggregator.link_personas} or
   * {@link IndividualAggregator.unlink_individual}, which will ensure the link
   * changes are written to the appropriate backend.
   */
  public GLib.List<Persona> personas
    {
      get { return this._persona_list; }
      set { this._set_personas (value, null); }
    }

  /**
   * Emitted when one or more {@link Persona}s are added to or removed from
   * the Individual.
   *
   * @param added a list of {@link Persona}s which have been added
   * @param removed a list of {@link Persona}s which have been removed
   *
   * @since 0.1.16
   */
  public signal void personas_changed (GLib.List<Persona>? added,
      GLib.List<Persona>? removed);

  private void notify_alias_cb (Object obj, ParamSpec ps)
    {
      this.update_alias ();
    }

  private void notify_avatar_cb (Object obj, ParamSpec ps)
    {
      this.update_avatar ();
    }

  private void persona_group_changed_cb (string group, bool is_member)
    {
      this.change_group.begin (group, is_member);
      this.update_groups ();
    }

  /**
   * Add or remove the Individual from the specified group.
   *
   * If `is_member` is `true`, the Individual will be added to the `group`. If
   * it is `false`, they will be removed from the `group`.
   *
   * The group membership change will propagate to every {@link Persona} in
   * the Individual.
   *
   * @param group a freeform group identifier
   * @param is_member whether the Individual should be a member of the group
   */
  public async void change_group (string group, bool is_member)
    {
      this._persona_list.foreach ((p) =>
        {
          if (p is Groups)
            ((Groups) p).change_group.begin (group, is_member);
        });

      /* don't notify, since it hasn't happened in the persona backing stores
       * yet; react to that directly */
    }

  private void notify_presence_cb (Object obj, ParamSpec ps)
    {
      this.update_presence ();
    }

  private void notify_is_favourite_cb (Object obj, ParamSpec ps)
    {
      this.update_is_favourite ();
    }

  /**
   * Create a new Individual.
   *
   * The Individual can optionally be seeded with the {@link Persona}s in
   * `personas`. Otherwise, it will have to have personas added using the
   * {@link Folks.Individual.personas} property after construction.
   *
   * @return a new Individual
   */
  public Individual (GLib.List<Persona>? personas)
    {
      this._persona_set = new HashSet<Persona> (null, null);
      this.stores = new HashMap<PersonaStore, uint> (null, null);
      this.personas = personas;
    }

  private void store_removed_cb (PersonaStore store)
    {
      GLib.List<Persona> removed_personas = null;
      Iterator<Persona> iter = this._persona_set.iterator ();
      while (iter.next ())
        {
          Persona persona = iter.get ();

          removed_personas.prepend (persona);
          this._persona_list.remove (persona);
          iter.remove ();
        }

      if (removed_personas != null)
        this.personas_changed (null, removed_personas);

      if (store != null)
        this.stores.remove (store);

      if (this._persona_set.size < 1)
        {
          this.removed (null);
          return;
        }

      this.update_fields ();
    }

  private void store_personas_changed_cb (PersonaStore store,
      GLib.List<Persona>? added,
      GLib.List<Persona>? removed,
      string? message,
      Persona? actor,
      Groups.ChangeReason reason)
    {
      GLib.List<Persona> removed_personas = null;
      removed.foreach ((data) =>
        {
          unowned Persona p = (Persona) data;

          if (this._persona_set.remove (p))
            {
              removed_personas.prepend (p);
              this._persona_list.remove (p);
            }
        });

      if (removed_personas != null)
        this.personas_changed (null, removed_personas);

      if (this._persona_set.size < 1)
        {
          this.removed (null);
          return;
        }

      this.update_fields ();
    }

  private void update_fields ()
    {
      this.update_groups ();
      this.update_presence ();
      this.update_is_favourite ();
      this.update_avatar ();
      this.update_alias ();
      this.update_trust_level ();
    }

  private void update_groups ()
    {
      var new_groups = new HashTable<string, bool> (str_hash, str_equal);

      /* this._groups is null during initial construction */
      if (this._groups == null)
        this._groups = new HashTable<string, bool> (str_hash, str_equal);

      /* FIXME: this should partition the personas by store (maybe we should
       * keep that mapping in general in this class), and execute
       * "groups-changed" on the store (with the set of personas), to allow the
       * back-end to optimize it (like Telepathy will for MembersChanged for the
       * groups channel list) */
      this._persona_list.foreach ((p) =>
        {
          if (p is Groups)
            {
              unowned Groups persona = (Groups) p;

              persona.groups.foreach ((k, v) =>
                {
                  new_groups.insert ((string) k, true);
                });
            }
        });

      new_groups.foreach ((k, v) =>
        {
          var group = (string) k;
          if (this._groups.lookup (group) != true)
            {
              this._groups.insert (group, true);
              this._groups.foreach ((k, v) =>
                {
                  var g = (string) k;
                  debug ("   %s", g);
                });

              this.group_changed (group, true);
            }
        });

      /* buffer the removals, so we don't remove while iterating */
      var removes = new GLib.List<string> ();
      this._groups.foreach ((k, v) =>
        {
          var group = (string) k;
          if (new_groups.lookup (group) != true)
            removes.prepend (group);
        });

      removes.foreach ((l) =>
        {
          var group = (string) l;
          this._groups.remove (group);
          this.group_changed (group, false);
        });
    }

  private void update_presence ()
    {
      var presence_message = "";
      var presence_type = Folks.PresenceType.UNSET;

      /* Choose the most available presence from our personas */
      this._persona_list.foreach ((p) =>
        {
          if (p is Presence)
            {
              unowned Presence presence = (Presence) p;

              if (Presence.typecmp (presence.presence_type, presence_type) > 0)
                {
                  presence_type = presence.presence_type;
                  presence_message = presence.presence_message;
                }
            }
        });

      if (presence_message == null)
        presence_message = "";

      /* only notify if the value has changed */
      if (this.presence_message != presence_message)
        this.presence_message = presence_message;

      if (this.presence_type != presence_type)
        this.presence_type = presence_type;
    }

  private void update_is_favourite ()
    {
      bool favourite = false;

      this._persona_list.foreach ((p) =>
        {
          if (favourite == false && p is Favourite)
            {
              favourite = ((Favourite) p).is_favourite;
              if (favourite == true)
                return;
            }
        });

      /* Only notify if the value has changed */
      if (this.is_favourite != favourite)
        this.is_favourite = favourite;
    }

  private void update_alias ()
    {
      string alias = null;
      bool alias_is_display_id = false;

      /* Search for an alias from a writeable Persona, and use it as our first
       * choice if it's non-empty, since that's where the user-set alias is
       * stored. */
      foreach (Persona p in this._persona_list)
        {
          if (p is Alias && p.store.is_writeable == true)
            {
              unowned Alias a = (Alias) p;

              if (a.alias != null && a.alias.strip () != "")
                {
                  alias = a.alias;

                  /* Only notify if the value has changed */
                  if (this.alias != alias)
                    this.alias = alias;

                  return;
                }
            }
        }

      /* Since we can't find a non-empty alias from a writeable backend, try
       * the aliases from other personas. Use a non-empty alias which isn't
       * equal to the persona's display ID as our preference. If we can't find
       * one of those, fall back to one which is equal to the display ID. */
      foreach (Persona p in this._persona_list)
        {
          if (p is Alias)
            {
              unowned Alias a = (Alias) p;

              if (a.alias == null || a.alias.strip () == "")
                continue;

              if (alias == null || alias_is_display_id == true)
                {
                  /* We prefer to not have an alias which is the same as the
                   * Persona's display-id, since having such an alias implies
                   * that it's the default. However, we prefer using such an
                   * alias to using the Persona's UID, which is our ultimate
                   * fallback (below). */
                  alias = a.alias;

                  if (a.alias == p.display_id)
                    alias_is_display_id = true;
                  else if (alias != null)
                    break;
                }
            }
        }

      if (alias == null)
        {
          /* We have to pick a display ID, since none of the personas have an
           * alias available. Pick the display ID from the first persona in the
           * list. */
          alias = this._persona_list.data.display_id;
          debug ("No aliases available for individual; using display ID " +
              "instead: %s", alias);
        }

      /* only notify if the value has changed */
      if (this.alias != alias)
        this.alias = alias;
    }

  private void update_avatar ()
    {
      File avatar = null;

      this._persona_list.foreach ((p) =>
        {
          if (avatar == null && p is Avatar)
            {
              avatar = ((Avatar) p).avatar;
              return;
            }
        });

      /* only notify if the value has changed */
      if (this.avatar != avatar)
        this.avatar = avatar;
    }

  private void update_trust_level ()
    {
      TrustLevel trust_level = TrustLevel.PERSONAS;

      foreach (Persona p in this._persona_list)
        {
          if (p.store.trust_level == PersonaStoreTrust.NONE)
            trust_level = TrustLevel.NONE;
        }

      /* Only notify if the value has changed */
      if (this.trust_level != trust_level)
        this.trust_level = trust_level;
    }

  /*
   * GLib/C convenience functions (for built-in casting, etc.)
   */

  /**
   * Get the Individual's alias.
   *
   * The alias is a user-chosen name for the Individual; how the user wants that
   * Individual to be represented in UIs.
   *
   * @return the Individual's alias
   */
  public unowned string get_alias ()
    {
      return this.alias;
    }

  /**
   * Get a mapping of group ID to whether the Individual is a member.
   *
   * Freeform group IDs are mapped to a boolean which is `true` if the
   * Individual is a member of the group, and `false` otherwise.
   *
   * @return a mapping of group ID to membership status
   */
  public HashTable<string, bool> get_groups ()
    {
      Groups g = this;
      return g.groups;
    }

  /**
   * Get the Individual's current presence message.
   *
   * The presence message returned is from the same {@link Persona} which
   * provided the presence type returned by
   * {@link Individual.get_presence_type}.
   *
   * If none of the {@link Persona}s in the Individual have a presence message
   * set, an empty string is returned.
   *
   * @return the Individual's presence message
   */
  public unowned string get_presence_message ()
    {
      return this.presence_message;
    }

  /**
   * Get the Individual's current presence type.
   *
   * The presence type returned is from the same {@link Persona} which provided
   * the presence message returned by {@link Individual.get_presence_message}.
   *
   * If none of the {@link Persona}s in the Individual have a presence type set,
   * {@link PresenceType.UNSET} is returned.
   *
   * @return the Individual's presence type
   */
  public Folks.PresenceType get_presence_type ()
    {
      return this.presence_type;
    }

  /**
   * Whether the Individual is online.
   *
   * This will be `true` if any of the Individual's {@link Persona}s have a
   * presence type higher than {@link PresenceType.OFFLINE}, as determined by
   * {@link Presence.typecmp}.
   *
   * @return `true` if the Individual is online, `false` otherwise
   */
  public bool is_online ()
    {
      Presence p = this;
      return p.is_online ();
    }

  private void connect_to_persona (Persona persona)
    {
      persona.notify["alias"].connect (this.notify_alias_cb);
      persona.notify["avatar"].connect (this.notify_avatar_cb);
      persona.notify["presence-message"].connect (this.notify_presence_cb);
      persona.notify["presence-type"].connect (this.notify_presence_cb);
      persona.notify["is-favourite"].connect (this.notify_is_favourite_cb);

      if (persona is Groups)
        {
          ((Groups) persona).group_changed.connect (
              this.persona_group_changed_cb);
        }
    }

  private void disconnect_from_persona (Persona persona)
    {
      persona.notify["alias"].disconnect (this.notify_alias_cb);
      persona.notify["avatar"].disconnect (this.notify_avatar_cb);
      persona.notify["presence-message"].disconnect (
          this.notify_presence_cb);
      persona.notify["presence-type"].disconnect (this.notify_presence_cb);
      persona.notify["is-favourite"].disconnect (
          this.notify_is_favourite_cb);

      if (persona is Groups)
        {
          ((Groups) persona).group_changed.disconnect (
              this.persona_group_changed_cb);
        }
    }

  private void _set_personas (GLib.List<Persona>? persona_list,
      Individual? replacement_individual)
    {
      HashSet<Persona> persona_set = new HashSet<Persona> (null, null);
      GLib.List<Persona> added = null;
      GLib.List<Persona> removed = null;

      /* Determine which Personas have been added */
      foreach (Persona p in persona_list)
        {
          if (!this._persona_set.contains (p))
            {
              added.prepend (p);

              this._persona_set.add (p);
              this.connect_to_persona (p);

              /* Increment the Persona count for this PersonaStore */
              unowned PersonaStore store = p.store;
              uint num_from_store = this.stores.get (store);
              if (num_from_store == 0)
                {
                  this.stores.set (store, num_from_store + 1);
                }
              else
                {
                  this.stores.set (store, 1);

                  store.removed.connect (this.store_removed_cb);
                  store.personas_changed.connect (
                      this.store_personas_changed_cb);
                }
            }

          persona_set.add (p);
        }

      /* Determine which Personas have been removed */
      foreach (Persona p in this._persona_list)
        {
          if (!persona_set.contains (p))
            {
              removed.prepend (p);

              /* Decrement the Persona count for this PersonaStore */
              unowned PersonaStore store = p.store;
              uint num_from_store = this.stores.get (store);
              if (num_from_store > 1)
                {
                  this.stores.set (store, num_from_store - 1);
                }
              else
                {
                  store.removed.disconnect (this.store_removed_cb);
                  store.personas_changed.disconnect (
                      this.store_personas_changed_cb);

                  this.stores.unset (store);
                }

              this.disconnect_from_persona (p);
              this._persona_set.remove (p);
            }
        }

      /* Update the Persona list. We just copy the list given to us to save
       * repeated insertions/removals and also to ensure we retain the ordering
       * of the Personas we were given. */
      this._persona_list = persona_list.copy ();

      this.personas_changed (added, removed);

      /* If all the Personas have been removed, remove the Individual */
      if (this._persona_set.size < 1)
        {
          this.removed (replacement_individual);
            return;
        }

      /* TODO: Base this upon our ID in permanent storage, once we have that. */
      if (this.id == null && this._persona_list.data != null)
        this.id = this._persona_list.data.uid;

      /* Update our aggregated fields and notify the changes */
      this.update_fields ();
    }

  internal void replace (Individual replacement_individual)
    {
      this._set_personas (null, replacement_individual);
    }
}
