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
  private HashTable<string, bool> _groups;
  private GLib.List<Persona> _persona_list;
  private HashSet<Persona> _persona_set;
  private HashSet<PersonaStore> stores;
  private bool _is_favourite;
  private string _alias;

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

  private void notify_groups_cb (Object obj, ParamSpec ps)
    {
      this.update_groups ();
    }

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
      this.stores = new HashSet<PersonaStore> (null, null);
      this.personas = personas;
    }

  private void store_removed_cb (PersonaStore store)
    {
      Iterator<Persona> iter = this._persona_set.iterator ();
      while (iter.next ())
        {
          Persona persona = iter.get ();

          this._persona_list.remove (persona);
          /* FIXME: bgo#624249 means GLib.List leaks item references.
           * We probably eventually want to transition away from GLib.List
           * and use Gee.LinkedList, but that would mean exposing libgee
           * in the public API. */
          g_object_unref (persona);

          iter.remove ();
        }

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
      removed.foreach ((data) =>
        {
          unowned Persona p = (Persona) data;

          if (this._persona_set.remove (p))
            {
              this._persona_list.remove (p);
              /* FIXME: bgo#624249 means GLib.List leaks item references */
              g_object_unref (p);
            }
        });

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
          /* We have to pick a UID, since none of the personas have an alias
           * available. Pick the UID from the first persona in the list. */
          alias = this._persona_list.data.uid;
          debug ("No aliases available for individual; using UID instead: %s",
                   alias);
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

  private void _set_personas (GLib.List<Persona>? personas,
      Individual? replacement_individual)
    {
      /* Disconnect from all our previous personas */
      this._persona_list.foreach ((p) =>
        {
          unowned Persona persona = (Persona) p;

          persona.notify["alias"].disconnect (this.notify_alias_cb);
          persona.notify["avatar"].disconnect (this.notify_avatar_cb);
          persona.notify["presence-message"].disconnect (
              this.notify_presence_cb);
          persona.notify["presence-type"].disconnect (this.notify_presence_cb);
          persona.notify["is-favourite"].disconnect (
              this.notify_is_favourite_cb);
          persona.notify["groups"].disconnect (this.notify_groups_cb);

          if (p is Groups)
            {
              ((Groups) p).group_changed.disconnect (
                  this.persona_group_changed_cb);
            }

          /* Disconnect from this persona's store */
          if (this.stores.contains (persona.store))
            {
              persona.store.removed.disconnect (this.store_removed_cb);
              persona.store.personas_changed.disconnect (
                  this.store_personas_changed_cb);
              this.stores.remove (persona.store);
            }

          this._persona_set.remove (persona);
        });

      /* Connect to all the new Personas */
      this._persona_list = new GLib.List<Persona> ();
      personas.foreach ((p) =>
        {
          unowned Persona persona = (Persona) p;

          this._persona_list.prepend (persona);

          persona.notify["alias"].connect (this.notify_alias_cb);
          persona.notify["avatar"].connect (this.notify_avatar_cb);
          persona.notify["presence-message"].connect (this.notify_presence_cb);
          persona.notify["presence-type"].connect (this.notify_presence_cb);
          persona.notify["is-favourite"].connect (this.notify_is_favourite_cb);
          persona.notify["groups"].connect (this.notify_groups_cb);

          if (p is Groups)
            {
              ((Groups) p).group_changed.connect (
                  this.persona_group_changed_cb);
            }

          /* Connect to this persona's store */
          if (!this.stores.contains (persona.store))
            {
              persona.store.removed.connect (this.store_removed_cb);
              persona.store.personas_changed.connect (
                  this.store_personas_changed_cb);
              this.stores.add (persona.store);
            }

          this._persona_set.add (persona);
        });

      this._persona_list.reverse ();

      /* If all the personas have been removed, remove the individual */
      if (this._persona_set.size < 1)
        {
          this.removed (replacement_individual);
            return;
        }

      /* TODO: base this upon our ID in permanent storage, once we have that
       */
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
