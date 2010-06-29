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
public class Folks.Individual : Object, Alias, Avatar, Capabilities, Groups,
       Presence, Favourite
{
  private HashTable<string, bool> _groups;
  private GLib.List<Persona> _personas;
  private HashTable<PersonaStore, HashSet<Persona>> stores;
  private bool _is_favourite;

  /* XXX: should setting this push it down into the Persona (to foward along to
   * the actual store if possible?) */
  /**
   * {@inheritDoc}
   */
  public string alias { get; set; }

  /**
   * {@inheritDoc}
   */
  public File avatar { get; set; }

  /**
   * {@inheritDoc}
   */
  public CapabilitiesFlags capabilities { get; private set; }

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
   */
  public signal void removed ();

  /**
   * Whether this Individual is a user-defined favourite.
   *
   * This property is `true` if any of this Individual's {@link Persona}s are
   * favourites).
   *
   * When set, the value is propagated to all of this Individual's
   * {@link Persona}s.
   */
  public bool is_favourite
    {
      get { return this._is_favourite; }

      /* Propagate the new favourite status to every Persona, but only if it's
       * changed. */
      set
        {
          if (this._is_favourite == value)
            return;

          this._is_favourite = value;
          this._personas.foreach ((p) =>
            {
              if (p is Favourite)
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

      /* Propagate the list of new groups to every Persona in the individual
       * which implements the Groups interface */
      set
        {
          this._personas.foreach ((p) =>
            {
              if (p is Groups)
                ((Groups) p).groups = value;
            });
        }
    }

  /**
   * The set of {@link Persona}s encapsulated by this Individual.
   *
   * Changing the set of personas may cause updates to the aggregated properties
   * provided by the Individual, resulting in property notifications for them.
   */
  public GLib.List<Persona> personas
    {
      get { return this._personas; }

      set
        {
          /* Disconnect from all our previous personas */
          this._personas.foreach ((p) =>
            {
              var persona = (Persona) p;
              var groups = (p is Groups) ? (Groups) p : null;

              persona.notify["avatar"].disconnect (this.notify_avatar_cb);
              persona.notify["presence-message"].disconnect (
                  this.notify_presence_cb);
              persona.notify["presence-type"].disconnect (
                  this.notify_presence_cb);
              persona.notify["is-favourite"].disconnect (
                  this.notify_is_favourite_cb);
              groups.group_changed.disconnect (this.persona_group_changed_cb);
            });

          this._personas = value.copy ();

          /* If all the personas have been removed, remove the individual */
          if (this._personas.length () < 1)
            {
              this.removed ();
              return;
            }

          /* TODO: base this upon our ID in permanent storage, once we have that
           */
          if (this.id == null && this._personas.data != null)
            this.id = this._personas.data.iid;

          /* Connect to all the new personas */
          this._personas.foreach ((p) =>
            {
              var persona = (Persona) p;
              var groups = (p is Groups) ? (Groups) p : null;

              persona.notify["avatar"].connect (this.notify_avatar_cb);
              persona.notify["presence-message"].connect (
                  this.notify_presence_cb);
              persona.notify["presence-type"].connect (this.notify_presence_cb);
              persona.notify["is-favourite"].connect (
                  this.notify_is_favourite_cb);
              groups.group_changed.connect (this.persona_group_changed_cb);
            });

          /* Update our aggregated fields and notify the changes */
          this.update_fields ();
        }
    }

  private void notify_avatar_cb (Object obj, ParamSpec ps)
    {
      this.update_avatar ();
    }

  private void persona_group_changed_cb (string group, bool is_member)
    {
      this.change_group (group, is_member);
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
  public void change_group (string group, bool is_member)
    {
      this._personas.foreach ((p) =>
        {
          if (p is Groups)
            ((Groups) p).change_group (group, is_member);
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
      Object (personas: personas);

      this.stores = new HashTable<PersonaStore, HashSet<Persona>> (direct_hash,
          direct_equal);
      this.stores_update ();
    }

  private void stores_update ()
    {
      this._personas.foreach ((p) =>
        {
          var persona = (Persona) p;
          var store_is_new = false;
          var persona_set = this.stores.lookup (persona.store);
          if (persona_set == null)
            {
              persona_set = new HashSet<Persona> (direct_hash, direct_equal);
              store_is_new = true;
            }

          persona_set.add (persona);

          if (store_is_new)
            {
              this.stores.insert (persona.store, persona_set);

              persona.store.removed.connect (this.store_removed_cb);
              persona.store.personas_removed.connect (
                this.store_personas_removed_cb);
            }
        });
    }

  private void store_removed_cb (PersonaStore store)
    {
      var persona_set = this.stores.lookup (store);
      if (persona_set != null)
        {
          foreach (var persona in persona_set)
            {
              this._personas.remove (persona);
            }
        }
      if (store != null)
        this.stores.remove (store);

      if (this._personas.length () < 1 || this.stores.size () < 1)
        {
          this.removed ();
          return;
        }

      this.update_fields ();
    }

  private void store_personas_removed_cb (PersonaStore store,
      GLib.List<Persona> personas)
    {
      personas.foreach ((data) =>
        {
          this._personas.remove ((Persona) data);
        });

      if (this._personas.length () < 1)
        {
          this.removed ();
          return;
        }

      this.update_fields ();
    }

  private void update_fields ()
    {
      /* Gather the first occurrence of each field. We assume that there is
       * at least one persona in the list, since the Individual should've been
       * destroyed before now otherwise. */
      string alias = null;
      var caps = CapabilitiesFlags.NONE;
      this._personas.foreach ((persona) =>
        {
          var p = (Persona) persona;

          /* FIXME: also check to see if alias is just whitespace */
          if (alias == null)
            alias = p.alias;

          caps |= p.capabilities;
        });

      if (alias == null)
        {
          /* We have to pick a UID, since none of the personas have an alias
           * available. Pick the UID from the first persona in the list. */
          alias = this._personas.data.uid;
          warning ("No aliases available for individual; using UID instead: %s",
                   alias);
        }

      /* only notify if the value has changed */
      if (this.alias != alias)
        this.alias = alias;

      if (this.capabilities != caps)
        this.capabilities = caps;

      this.update_groups ();
      this.update_presence ();
      this.update_is_favourite ();
      this.update_avatar ();
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
      this._personas.foreach ((p) =>
        {
          if (p is Groups)
            {
              var persona = (Groups) p;

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
      this._personas.foreach ((p) =>
        {
          var persona = (Persona) p;

          if (Presence.typecmp (persona.presence_type, presence_type) > 0)
            {
              presence_type = persona.presence_type;
              presence_message = persona.presence_message;
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

      this._personas.foreach ((persona) =>
        {
          var p = (Persona) persona;

          if (favourite == false)
            favourite = p.is_favourite;
        });

      /* Only notify if the value has changed */
      if (this._is_favourite != favourite)
        this._is_favourite = favourite;
    }

  private void update_avatar ()
    {
      File avatar = null;

      this._personas.foreach ((p) =>
        {
          var persona = (Persona) p;

          if (avatar == null)
            {
              avatar = persona.avatar;
              return;
            }
        });

      /* only notify if the value has changed */
      if (this.avatar != avatar)
        this.avatar = avatar;
    }

  /**
   * Get a bitmask of the capabilities of this Individual.
   *
   * The capabilities is the union of the sets of capabilities of all the
   * {@link Persona}s in the Individual.
   *
   * @return bitmask of the Individual's capabilities
   */
  public CapabilitiesFlags get_capabilities ()
    {
      return this.capabilities;
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
}
