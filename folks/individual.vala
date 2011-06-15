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
 * Trust level for an {@link Individual} for use in the UI.
 *
 * @since 0.1.15
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
   * @since 0.1.15
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
   * @since 0.1.15
   */
  PERSONAS
}

/**
 * A physical person, aggregated from the various {@link Persona}s the person
 * might have, such as their different IM addresses or vCard entries.
 */
public class Folks.Individual : Object,
    AliasDetails,
    AvatarDetails,
    BirthdayDetails,
    EmailDetails,
    FavouriteDetails,
    GenderDetails,
    GroupDetails,
    ImDetails,
    LocalIdDetails,
    NameDetails,
    NoteDetails,
    PresenceDetails,
    PhoneDetails,
    PostalAddressDetails,
    RoleDetails,
    UrlDetails,
    WebServiceDetails
{
  private bool _is_favourite;
  private string _alias;
  private HashSet<string> _groups;
  /* Stores the Personas contained in this Individual. */
  private HashSet<Persona> _persona_set;
  /* Read-only view of the above set */
  private Set<Persona> _persona_set_ro;
  /* Mapping from PersonaStore -> number of Personas from that store contained
   * in this Individual. There shouldn't be any entries with a number < 1.
   * This is used for working out when to disconnect from store signals. */
  private HashMap<PersonaStore, uint> _stores;
  /* The number of Personas in this Individual which have
   * Persona.is_user == true. Iff this is > 0, Individual.is_user == true. */
  private uint _persona_user_count = 0;
  private HashMultiMap<string, string> _im_addresses;
  private HashMultiMap<string, string> _web_service_addresses;

  /**
   * The trust level of the Individual.
   *
   * This specifies how far the Individual can be trusted to be who it claims
   * to be. See the descriptions for the elements of {@link TrustLevel}.
   *
   * Clients should ''not'' allow linking of Individuals who have a trust level
   * of {@link TrustLevel.NONE}.
   *
   * @since 0.1.15
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
   *
   * @since 0.5.UNRELEASED
   */
  public string presence_status { get; private set; }

  /**
   * {@inheritDoc}
   */
  public string presence_message { get; private set; }

  /**
   * Whether the Individual is the user.
   *
   * Iff the Individual represents the user (the person who owns the
   * account in the backend for each {@link Persona} in the Individual)
   * this is `true`.
   *
   * It is //not// guaranteed that every {@link Persona} in the Individual has
   * its {@link Persona.is_user} set to the same value as the Individual. For
   * example, the user could own two Telepathy accounts, and have added the
   * other account as a contact in each account. The accounts will expose a
   * {@link Persona} for the user (which will have {@link Persona.is_user} set
   * to `true`) //and// a {@link Persona} for the contact for the other account
   * (which will have {@link Persona.is_user} set to `false`).
   *
   * It is guaranteed that iff this property is set to `true` on an Individual,
   * there will be at least one {@link Persona} in the Individual with its
   * {@link Persona.is_user} set to `true`.
   *
   * It is guaranteed that there will only ever be one Individual with this
   * property set to `true`.
   *
   * @since 0.3.0
   */
  public bool is_user { get; private set; }

  /**
   * A unique identifier for the Individual.
   *
   * This uniquely identifies the Individual, and persists across
   * {@link IndividualAggregator} instances. It may not persist across linking
   * the Individual with other Individuals.
   *
   * This is an opaque string and has no structure.
   *
   * If an identifier is required which will be used for a long-lived link
   * between different stored data, it may be more desirable to use the
   * {@link Persona.uid} of the most relevant {@link Persona} in the Individual
   * instead. For example, if storing references to Individuals who are tagged
   * in a photo, it may be safer to store the UID of the Persona whose backend
   * provided the photo (e.g. Facebook).
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
   * @since 0.1.13
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

          debug ("Setting alias of individual '%s' to '%s'…", this.id, value);

          /* First, try to write it to only the writeable Personas… */
          var alias_changed = false;
          foreach (var p in this._persona_set)
            {
              if (p is AliasDetails &&
                  ((Persona) p).store.is_writeable == true)
                {
                  debug ("    written to writeable persona '%s'",
                      ((Persona) p).uid);
                  ((AliasDetails) p).alias = value;
                  alias_changed = true;
                }
            }

          /* …but if there are no writeable Personas, we have to fall back to
           * writing it to every Persona. */
          if (alias_changed == false)
            {
              foreach (var p in this._persona_set)
                {
                  if (p is AliasDetails)
                    {
                      debug ("    written to non-writeable persona '%s'",
                          ((Persona) p).uid);
                      ((AliasDetails) p).alias = value;
                    }
                }
            }
        }
    }

  /**
   * {@inheritDoc}
   */
  public StructuredName structured_name { get; private set; }

  /**
   * {@inheritDoc}
   */
  public string full_name { get; private set; }

  private string _nickname;
  /**
   * {@inheritDoc}
   */
  public string nickname { get { return this._nickname; } }

  private Gender _gender;
  /**
   * {@inheritDoc}
   */
  public Gender gender
    {
      get { return this._gender; }
      private set
        {
          this._gender = value;
          this.notify_property ("gender");
        }
    }

  private HashSet<FieldDetails> _urls;
  /**
   * {@inheritDoc}
   */
  public Set<FieldDetails> urls
    {
      get { return this._urls; }
      private set
        {
          this._urls = new HashSet<FieldDetails> ();
          foreach (var ps in value)
            this._urls.add (ps);
        }
    }

  private HashSet<FieldDetails> _phone_numbers;

  /**
   * {@inheritDoc}
   */
  public Set<FieldDetails> phone_numbers
    {
      get { return this._phone_numbers; }
      private set
        {
          this._phone_numbers = new HashSet<FieldDetails> ();
          foreach (var fd in value)
            this._phone_numbers.add (fd);
        }
    }

  private HashSet<FieldDetails> _email_addresses;
  /**
   * {@inheritDoc}
   */
  public Set<FieldDetails> email_addresses
    {
      get { return this._email_addresses; }
      private set
        {
          this._email_addresses = new HashSet<FieldDetails> ();
          foreach (var fd in value)
            this._email_addresses.add (fd);
        }
    }

  private HashSet<Role> _roles;

  /**
   * {@inheritDoc}
   */
  public Set<Role> roles
    {
      get { return this._roles; }
      private set
        {
          this._roles = new HashSet<Role> ();
          foreach (var role in value)
            this._roles.add (role);
          this.notify_property ("roles");
        }
    }

  private HashSet<string> _local_ids;

  /**
   * {@inheritDoc}
   */
  public Set<string> local_ids
    {
      get { return this._local_ids; }
      private set
        {
          this._local_ids = new HashSet<string> ();
          foreach (var id in value)
            this._local_ids.add (id);
          this.notify_property ("local-ids");
        }
    }

  public DateTime birthday { get; set; }

  public string calendar_event_id { get; set; }

  private HashSet<Note> _notes;

  /**
   * {@inheritDoc}
   */
  public Set<Note> notes
    {
      get { return this._notes; }
      private set
        {
          this._notes = new HashSet<Note> ();
          foreach (var note in value)
            this._notes.add (note);
          this.notify_property ("notes");
        }
    }

  private HashSet<PostalAddress> _postal_addresses;
  /**
   * {@inheritDoc}
   */
  public Set<PostalAddress> postal_addresses
    {
      get { return this._postal_addresses; }
      private set
        {
          this._postal_addresses = new HashSet<PostalAddress> ();
          foreach (PostalAddress pa in value)
            this._postal_addresses.add (pa);
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

          debug ("Setting '%s' favourite status to %s", this.id,
              value ? "TRUE" : "FALSE");

          this._is_favourite = value;
          foreach (var p in this._persona_set)
            {
              if (p is FavouriteDetails)
                {
                  SignalHandler.block_by_func (p,
                      (void*) this._notify_is_favourite_cb, this);
                  ((FavouriteDetails) p).is_favourite = value;
                  SignalHandler.unblock_by_func (p,
                      (void*) this._notify_is_favourite_cb, this);
                }
            }
        }
    }

  /**
   * {@inheritDoc}
   */
  public Set<string> groups
    {
      get { return this._groups; }

      set
        {
          foreach (var p in this._persona_set)
            {
              if (p is GroupDetails && ((Persona) p).store.is_writeable == true)
                ((GroupDetails) p).groups = value;
            }
          this._update_groups ();
        }
    }

  /**
   * {@inheritDoc}
   */
  public MultiMap<string, string> im_addresses
    {
      get { return this._im_addresses; }
      private set {}
    }

  /**
   * {@inheritDoc}
   */
  public MultiMap<string, string> web_service_addresses
    {
      get { return this._web_service_addresses; }
      private set {}
    }

  /**
   * The set of {@link Persona}s encapsulated by this Individual.
   *
   * No order is specified over the set of personas, as such an order may be
   * different across each of the properties implemented by the personas (e.g.
   * should they be ordered by presence, name, star sign, etc.?).
   *
   * Changing the set of personas may cause updates to the aggregated properties
   * provided by the Individual, resulting in property notifications for them.
   *
   * Changing the set of personas will not cause permanent linking/unlinking of
   * the added/removed personas to/from this Individual. To do that, call
   * {@link IndividualAggregator.link_personas} or
   * {@link IndividualAggregator.unlink_individual}, which will ensure the link
   * changes are written to the appropriate backend.
   *
   * @since 0.5.1
   */
  public Set<Persona> personas
    {
      get { return this._persona_set_ro; }
      set { this._set_personas (value, null); }
    }

  /**
   * Emitted when one or more {@link Persona}s are added to or removed from
   * the Individual. As the parameters are (unordered) sets, the orders of their
   * elements are undefined.
   *
   * @param added a set of {@link Persona}s which have been added
   * @param removed a set of {@link Persona}s which have been removed
   *
   * @since 0.5.1
   */
  public signal void personas_changed (Set<Persona> added,
      Set<Persona> removed);

  private void _notify_alias_cb (Object obj, ParamSpec ps)
    {
      this._update_alias ();
    }

  private void _notify_avatar_cb (Object obj, ParamSpec ps)
    {
      this._update_avatar ();
    }

  private void _notify_full_name_cb ()
    {
      this._update_full_name ();
    }

  private void _notify_structured_name_cb ()
    {
      this._update_structured_name ();
    }

  private void _notify_nickname_cb ()
    {
      this._update_nickname ();
    }

  private void _persona_group_changed_cb (string group, bool is_member)
    {
      this._update_groups ();
    }

  private void _notify_gender_cb ()
    {
      this._update_gender ();
    }

  private void _notify_urls_cb ()
    {
      this._update_urls ();
    }

  private void _notify_phone_numbers_cb ()
    {
      this._update_phone_numbers ();
    }

  private void _notify_postal_addresses_cb ()
    {
      this._update_postal_addresses ();
    }

  private void _notify_email_addresses_cb ()
    {
      this._update_email_addresses ();
    }

  private void _notify_roles_cb ()
    {
      this._update_roles ();
    }

  private void _notify_birthday_cb ()
    {
      this._update_birthday ();
    }

  private void _notify_notes_cb ()
    {
      this._update_notes ();
    }

  private void _notify_local_ids_cb ()
    {
      this._update_local_ids ();
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
   * @since 0.1.11
   */
  public async void change_group (string group, bool is_member)
    {
      foreach (var p in this._persona_set)
        {
          if (p is GroupDetails)
            ((GroupDetails) p).change_group.begin (group, is_member);
        }

      /* don't notify, since it hasn't happened in the persona backing stores
       * yet; react to that directly */
    }

  private void _notify_presence_cb (Object obj, ParamSpec ps)
    {
      this._update_presence ();
    }

  private void _notify_im_addresses_cb (Object obj, ParamSpec ps)
    {
      this._update_im_addresses ();
    }

  private void _notify_web_service_addresses_cb (Object obj, ParamSpec ps)
    {
      this._update_web_service_addresses ();
    }

  private void _notify_is_favourite_cb (Object obj, ParamSpec ps)
    {
      this._update_is_favourite ();
    }

  /**
   * Create a new Individual.
   *
   * The Individual can optionally be seeded with the {@link Persona}s in
   * `personas`. Otherwise, it will have to have personas added using the
   * {@link Folks.Individual.personas} property after construction.
   *
   * @param personas a list of {@link Persona}s to initialise the
   * {@link Individual} with, or `null`
   * @return a new Individual
   *
   * @since 0.5.1
   */
  public Individual (Set<Persona>? personas)
    {
      this._im_addresses = new HashMultiMap<string, string> ();
      this._web_service_addresses = new HashMultiMap<string, string> ();
      this._persona_set =
          new HashSet<Persona> (direct_hash, direct_equal);
      this._persona_set_ro = this._persona_set.read_only_view;
      this._stores = new HashMap<PersonaStore, uint> (null, null);
      this._gender = Gender.UNSPECIFIED;
      this._urls = new HashSet<FieldDetails> ();
      this._phone_numbers = new HashSet<FieldDetails> ();
      this._email_addresses = new HashSet<FieldDetails> ();
      this._roles = new HashSet<Role>
          ((GLib.HashFunc) Role.hash, (GLib.EqualFunc) Role.equal);
      this._local_ids = new HashSet<string> ();
      this._postal_addresses = new HashSet<PostalAddress> ();
      this._notes = new HashSet<Note>
          ((GLib.HashFunc) Note.hash, (GLib.EqualFunc) Note.equal);

      this.personas = personas;
    }

  /* Emit the personas-changed signal, turning null parameters into empty sets
   * and ensuring that the signal is emitted with read-only views of the sets
   * so that signal handlers can't modify the sets. */
  private void _emit_personas_changed (Set<Persona>? added,
      Set<Persona>? removed)
    {
      var _added = added;
      var _removed = removed;

      if ((added == null || added.size == 0) &&
          (removed == null || removed.size == 0))
        {
          /* Emitting it with no added or removed personas is pointless */
          return;
        }
      else if (added == null)
        {
          _added = new HashSet<Persona> ();
        }
      else if (removed == null)
        {
          _removed = new HashSet<Persona> ();
        }

      this.personas_changed (_added.read_only_view, _removed.read_only_view);
    }

  private void _store_removed_cb (PersonaStore store)
    {
      var removed_personas = new HashSet<Persona> ();
      var iter = this._persona_set.iterator ();
      while (iter.next ())
        {
          var persona = iter.get ();

          removed_personas.add (persona);
          iter.remove ();
        }

      if (removed_personas != null)
        this._emit_personas_changed (null, removed_personas);

      if (store != null)
        this._stores.unset (store);

      if (this._persona_set.size < 1)
        {
          this.removed (null);
          return;
        }

      this._update_fields ();
    }

  private void _store_personas_changed_cb (PersonaStore store,
      Set<Persona> added,
      Set<Persona> removed,
      string? message,
      Persona? actor,
      GroupDetails.ChangeReason reason)
    {
      var removed_personas = new HashSet<Persona> ();
      foreach (var p in removed)
        {
          if (this._persona_set.remove (p))
            {
              removed_personas.add (p);
            }
        }

      if (removed_personas != null)
        this._emit_personas_changed (null, removed_personas);

      if (this._persona_set.size < 1)
        {
          this.removed (null);
          return;
        }

      this._update_fields ();
    }

  private void _update_fields ()
    {
      this._update_groups ();
      this._update_presence ();
      this._update_is_favourite ();
      this._update_avatar ();
      this._update_alias ();
      this._update_trust_level ();
      this._update_im_addresses ();
      this._update_web_service_addresses ();
      this._update_structured_name ();
      this._update_full_name ();
      this._update_nickname ();
      this._update_gender ();
      this._update_urls ();
      this._update_phone_numbers ();
      this._update_email_addresses ();
      this._update_roles ();
      this._update_birthday ();
      this._update_notes ();
      this._update_postal_addresses ();
      this._update_local_ids ();
    }

  private void _update_groups ()
    {
      var new_groups = new HashSet<string> ();

      /* this._groups is null during initial construction */
      if (this._groups == null)
        this._groups = new HashSet<string> ();

      /* FIXME: this should partition the personas by store (maybe we should
       * keep that mapping in general in this class), and execute
       * "groups-changed" on the store (with the set of personas), to allow the
       * back-end to optimize it (like Telepathy will for MembersChanged for the
       * groups channel list) */
      foreach (var p in this._persona_set)
        {
          if (p is GroupDetails)
            {
              var persona = (GroupDetails) p;

              foreach (var group in persona.groups)
                {
                  new_groups.add (group);
                }
            }
        }

      foreach (var group in new_groups)
        {
          if (!this._groups.contains (group))
            {
              this._groups.add (group);
              foreach (var g in this._groups)
                {
                  debug ("   %s", g);
                }

              this.group_changed (group, true);
            }
        }

      /* buffer the removals, so we don't remove while iterating */
      var removes = new GLib.List<string> ();
      foreach (var group in this._groups)
        {
          if (!new_groups.contains (group))
            removes.prepend (group);
        }

      removes.foreach ((l) =>
        {
          unowned string group = (string) l;
          this._groups.remove (group);
          this.group_changed (group, false);
        });
    }

  private void _update_presence ()
    {
      var presence_message = "";
      var presence_status = "";
      var presence_type = Folks.PresenceType.UNSET;

      /* Choose the most available presence from our personas */
      foreach (var p in this._persona_set)
        {
          if (p is PresenceDetails)
            {
              unowned PresenceDetails presence = (PresenceDetails) p;

              if (PresenceDetails.typecmp (presence.presence_type,
                  presence_type) > 0)
                {
                  presence_type = presence.presence_type;
                  presence_message = presence.presence_message;
                  presence_status = presence.presence_status;
                }
            }
        }

      if (presence_message == null)
        presence_message = "";
      if (presence_status == null)
        presence_status = "";

      /* only notify if the value has changed */
      if (this.presence_message != presence_message)
        this.presence_message = presence_message;

      if (this.presence_type != presence_type)
        this.presence_type = presence_type;

      if (this.presence_status != presence_status)
        this.presence_status = presence_status;
    }

  private void _update_is_favourite ()
    {
      var favourite = false;

      debug ("Running _update_is_favourite() on '%s'", this.id);

      foreach (var p in this._persona_set)
        {
          if (favourite == false && p is FavouriteDetails)
            {
              favourite = ((FavouriteDetails) p).is_favourite;
              if (favourite == true)
                break;
            }
        }

      /* Only notify if the value has changed. We have to set the private member
       * and notify manually, or we'd end up propagating the new favourite
       * status back down to all our Personas. */
      if (this._is_favourite != favourite)
        {
          this._is_favourite = favourite;
          this.notify_property ("is-favourite");
        }
    }

  private void _update_alias ()
    {
      string alias = null;
      var alias_is_display_id = false;

      debug ("Updating alias for individual '%s'", this.id);

      /* Search for an alias from a writeable Persona, and use it as our first
       * choice if it's non-empty, since that's where the user-set alias is
       * stored. */
      foreach (var p in this._persona_set)
        {
          if (p is AliasDetails && p.store.is_writeable == true)
            {
              var a = (AliasDetails) p;

              if (a.alias != null && a.alias.strip () != "")
                {
                  alias = a.alias;
                  break;
                }
            }
        }

      debug ("    got alias '%s' from writeable personas", alias);

      /* Since we can't find a non-empty alias from a writeable backend, try
       * the aliases from other personas. Use a non-empty alias which isn't
       * equal to the persona's display ID as our preference. If we can't find
       * one of those, fall back to one which is equal to the display ID. */
      if (alias == null)
        {
          foreach (var p in this._persona_set)
            {
              if (p is AliasDetails)
                {
                  var a = (AliasDetails) p;

                  if (a.alias == null || a.alias.strip () == "")
                    continue;

                  if (alias == null || alias_is_display_id == true)
                    {
                      /* We prefer to not have an alias which is the same as the
                       * Persona's display-id, since having such an alias
                       * implies that it's the default. However, we prefer using
                       * such an alias to using the Persona's UID, which is our
                       * ultimate fallback (below). */
                      alias = a.alias;

                      if (a.alias == p.display_id)
                        alias_is_display_id = true;
                      else if (alias != null)
                        break;
                    }
                }
            }
        }

      debug ("    got alias '%s' from non-writeable personas", alias);

      if (alias == null)
        {
          /* We have to pick a display ID, since none of the personas have an
           * alias available. Pick the display ID from the first persona in the
           * list. */
          foreach (var persona in this._persona_set)
            {
              alias = persona.display_id;
              debug ("No aliases available for individual; using display ID " +
                  "instead: %s", alias);
              break;
            }
        }

      /* Only notify if the value has changed. We have to set the private member
       * and notify manually, or we'd end up propagating the new alias back
       * down to all our Personas, even if it's a fallback display ID or
       * something else undesirable. */
      if (this._alias != alias)
        {
          debug ("Changing alias of individual '%s' from '%s' to '%s'.",
              this.id, this._alias, alias);
          this._alias = alias;
          this.notify_property ("alias");
        }
    }

  private void _update_avatar ()
    {
      File avatar = null;

      foreach (var p in this._persona_set)
        {
          if (p is AvatarDetails)
            {
              avatar = ((AvatarDetails) p).avatar;
              if (avatar != null)
                break;
            }
        }

      /* only notify if the value has changed */
      if (this.avatar != avatar)
        this.avatar = avatar;
    }

  private void _update_trust_level ()
    {
      var trust_level = TrustLevel.PERSONAS;

      foreach (var p in this._persona_set)
        {
          if (p.is_user == false &&
              p.store.trust_level == PersonaStoreTrust.NONE)
            trust_level = TrustLevel.NONE;
        }

      /* Only notify if the value has changed */
      if (this.trust_level != trust_level)
        this.trust_level = trust_level;
    }

  private void _update_im_addresses ()
    {
      /* populate the IM addresses as the union of our Personas' addresses */
      this._im_addresses.clear ();

      foreach (var persona in this._persona_set)
        {
          if (persona is ImDetails)
            {
              var im_details = (ImDetails) persona;
              foreach (var cur_protocol in im_details.im_addresses.get_keys ())
                {
                  var cur_addresses =
                      im_details.im_addresses.get (cur_protocol);

                  foreach (var address in cur_addresses)
                    {
                      this._im_addresses.set (cur_protocol, address);
                    }
                }
            }
        }
      this.notify_property ("im-addresses");
    }

  private void _update_web_service_addresses ()
    {
      /* populate the web service addresses as the union of our Personas' addresses */
      this._web_service_addresses.clear ();

      foreach (var persona in this.personas)
        {
          if (persona is WebServiceDetails)
            {
              var web_service_details = (WebServiceDetails) persona;
              foreach (var cur_web_service in
                  web_service_details.web_service_addresses.get_keys ())
                {
                  var cur_addresses =
                      web_service_details.web_service_addresses.get (
                          cur_web_service);

                  foreach (var address in cur_addresses)
                    {
                      this._web_service_addresses.set (cur_web_service,
                          address);
                    }
                }
            }
        }
      this.notify_property ("web-service-addresses");
    }

  private void _connect_to_persona (Persona persona)
    {
      persona.notify["alias"].connect (this._notify_alias_cb);
      persona.notify["avatar"].connect (this._notify_avatar_cb);
      persona.notify["presence-message"].connect (this._notify_presence_cb);
      persona.notify["presence-type"].connect (this._notify_presence_cb);
      persona.notify["im-addresses"].connect (this._notify_im_addresses_cb);
      persona.notify["web-service-addresses"].connect
              (this._notify_web_service_addresses_cb);
      persona.notify["is-favourite"].connect (this._notify_is_favourite_cb);
      persona.notify["structured-name"].connect (
          this._notify_structured_name_cb);
      persona.notify["full-name"].connect (this._notify_full_name_cb);
      persona.notify["nickname"].connect (this._notify_nickname_cb);
      persona.notify["gender"].connect (this._notify_gender_cb);
      persona.notify["urls"].connect (this._notify_urls_cb);
      persona.notify["phone-numbers"].connect (this._notify_phone_numbers_cb);
      persona.notify["email-addresses"].connect (
          this._notify_email_addresses_cb);
      persona.notify["roles"].connect (this._notify_roles_cb);
      persona.notify["birthday"].connect (this._notify_birthday_cb);
      persona.notify["notes"].connect (this._notify_notes_cb);
      persona.notify["postal-addresses"].connect
          (this._notify_postal_addresses_cb);
      persona.notify["local-ids"].connect
          (this._notify_local_ids_cb);


      if (persona is GroupDetails)
        {
          ((GroupDetails) persona).group_changed.connect (
              this._persona_group_changed_cb);
        }
    }

  private void _update_structured_name ()
    {
      bool name_found = false;

      foreach (var persona in this._persona_set)
        {
          var name_details = persona as NameDetails;
          if (name_details != null)
            {
              var new_value = name_details.structured_name;
              if (new_value != null && !new_value.is_empty ())
                {
                  name_found = true;
                  if (this.structured_name == null ||
                      !this.structured_name.equal (new_value))
                    {
                      this.structured_name = new_value;
                      return;
                    }
                }
            }
        }

      if (name_found == false)
        this.structured_name = null;
    }

  private void _update_full_name ()
    {
      string? new_full_name = null;

      foreach (var persona in this._persona_set)
        {
          var name_details = persona as NameDetails;
          if (name_details != null)
            {
              var new_value = name_details.full_name;
              if (new_value != null && new_value != "")
                {
                  new_full_name = new_value;
                  break;
                }
            }
        }

      if (new_full_name != this.full_name)
        this.full_name = new_full_name;
    }

  private void _update_nickname ()
    {
      string? new_nickname = null;

      foreach (var persona in this._persona_set)
        {
          var name_details = persona as NameDetails;
          if (name_details != null)
            {
              var new_value = name_details.nickname;
              if (new_value != null && new_value != "")
                {
                  new_nickname = new_value;
                  break;
                }
            }
        }

      if (new_nickname != this._nickname)
        {
          this._nickname = new_nickname;
          this.notify_property ("nickname");
        }
    }

  private void _disconnect_from_persona (Persona persona)
    {
      persona.notify["alias"].disconnect (this._notify_alias_cb);
      persona.notify["avatar"].disconnect (this._notify_avatar_cb);
      persona.notify["presence-message"].disconnect (
          this._notify_presence_cb);
      persona.notify["presence-type"].disconnect (this._notify_presence_cb);
      persona.notify["im-addresses"].disconnect (
          this._notify_im_addresses_cb);
      persona.notify["web-service-addresses"].disconnect (
          this._notify_web_service_addresses_cb);
      persona.notify["is-favourite"].disconnect (
          this._notify_is_favourite_cb);
      persona.notify["structured-name"].disconnect (
          this._notify_structured_name_cb);
      persona.notify["full-name"].disconnect (this._notify_full_name_cb);
      persona.notify["nickname"].disconnect (this._notify_nickname_cb);
      persona.notify["gender"].disconnect (this._notify_gender_cb);
      persona.notify["urls"].disconnect (this._notify_urls_cb);
      persona.notify["phone-numbers"].disconnect (
          this._notify_phone_numbers_cb);
      persona.notify["email-addresses"].disconnect (
          this._notify_email_addresses_cb);
      persona.notify["roles"].disconnect (this._notify_roles_cb);
      persona.notify["birthday"].disconnect (this._notify_birthday_cb);
      persona.notify["notes"].disconnect (this._notify_notes_cb);
      persona.notify["postal-addresses"].disconnect
          (this._notify_postal_addresses_cb);
      persona.notify["local-ids"].disconnect (this._notify_local_ids_cb);


      if (persona is GroupDetails)
        {
          ((GroupDetails) persona).group_changed.disconnect (
              this._persona_group_changed_cb);
        }
    }

  private void _update_gender ()
    {
      Gender new_gender = Gender.UNSPECIFIED;

      foreach (var persona in this._persona_set)
        {
          var gender_details = persona as GenderDetails;
          if (gender_details != null)
            {
              var new_value = gender_details.gender;
              if (new_value != Gender.UNSPECIFIED)
                {
                  new_gender = new_value;
                  break;
                }
            }
        }

      if (new_gender != this.gender)
        this.gender = new_gender;
    }

  private void _update_urls ()
    {
      /* Populate the URLs as the union of our Personas' URLs.
       * If the same URL exists multiple times we merge the parameters. */
      var urls_set = new HashMap<unowned string, unowned FieldDetails> ();

      this._urls.clear ();

      foreach (var persona in this._persona_set)
        {
          var url_details = persona as UrlDetails;
          if (url_details != null)
            {
              foreach (var ps in url_details.urls)
                {
                  if (ps.value == null)
                    continue;

                  var existing = urls_set.get (ps.value);
                  if (existing != null)
                    existing.extend_parameters (ps.parameters);
                  else
                    {
                      var new_ps = new FieldDetails (ps.value);
                      new_ps.extend_parameters (ps.parameters);
                      urls_set.set (ps.value, new_ps);
                      this._urls.add (new_ps);
                    }
                }
            }
        }

      this.notify_property ("urls");
    }

  private void _update_phone_numbers ()
    {
      /* Populate the phone numbers as the union of our Personas' numbers
       * If the same number exists multiple times we merge the parameters. */
      /* FIXME: We should handle phone numbers better, just string comparison
         doesn't work. */
      var phone_numbers_set =
          new HashMap<unowned string, unowned FieldDetails> ();

      this._phone_numbers.clear ();

      foreach (var persona in this._persona_set)
        {
          var phone_details = persona as PhoneDetails;
          if (phone_details != null)
            {
              foreach (var fd in phone_details.phone_numbers)
                {
                  if (fd.value == null)
                    continue;

                  var existing = phone_numbers_set.get (fd.value);
                  if (existing != null)
                    existing.extend_parameters (fd.parameters);
                  else
                    {
                      var new_fd = new FieldDetails (fd.value);
                      new_fd.extend_parameters (fd.parameters);
                      phone_numbers_set.set (fd.value, new_fd);
                      this._phone_numbers.add (new_fd);
                    }
                }
            }
        }

      this.notify_property ("phone-numbers");
    }

  private void _update_email_addresses ()
    {
      /* Populate the email addresses as the union of our Personas' addresses.
       * If the same address exists multiple times we merge the parameters. */
      var emails_set = new HashMap<unowned string, unowned FieldDetails> ();

      this._email_addresses.clear ();

      foreach (var persona in this._persona_set)
        {
          var email_details = persona as EmailDetails;
          if (email_details != null)
            {
              foreach (var fd in email_details.email_addresses)
                {
                  if (fd.value == null)
                    continue;

                  var existing = emails_set.get (fd.value);
                  if (existing != null)
                    existing.extend_parameters (fd.parameters);
                  else
                    {
                      var new_fd = new FieldDetails (fd.value);
                      new_fd.extend_parameters (fd.parameters);
                      emails_set.set (fd.value, new_fd);
                      this._email_addresses.add (new_fd);
                    }
                }
            }
        }

      this.notify_property ("email-addresses");
    }

  private void _update_roles ()
    {
      this._roles.clear ();

      foreach (var persona in this._persona_set)
        {
          var role_details = persona as RoleDetails;
          if (role_details != null)
            {
              foreach (var r in role_details.roles)
                {
                  this._roles.add (r);
                }
            }
        }

      this.notify_property ("roles");
    }

  private void _update_local_ids ()
    {
      this._local_ids.clear ();

      foreach (var persona in this._persona_set)
        {
          var local_ids_details = persona as LocalIdDetails;
          if (local_ids_details != null)
            {
              foreach (var id in local_ids_details.local_ids)
                {
                  this._local_ids.add (id);
                }
            }
        }

      this.notify_property ("local-ids");
    }

  private void _update_postal_addresses ()
    {
      this._postal_addresses.clear ();

      /* FIXME: Detect duplicates somehow? */
      foreach (var persona in this._persona_set)
        {
          var address_details = persona as PostalAddressDetails;
          if (address_details != null)
            {
              foreach (var pa in address_details.postal_addresses)
                this._postal_addresses.add (pa);
            }
        }

      this.notify_property ("postal-addresses");
    }

  private void _update_birthday ()
    {
      unowned DateTime bday = null;
      unowned string calendar_event_id = "";

      foreach (var persona in this._persona_set)
        {
          var bday_owner = persona as BirthdayDetails;
          if (bday_owner != null)
            {
              if (bday_owner.birthday != null)
                {
                  if (this.birthday == null ||
                      bday_owner.birthday.compare (this.birthday) != 0)
                    {
                      bday = bday_owner.birthday;
                      calendar_event_id = bday_owner.calendar_event_id;
                      break;
                    }
                }
            }
        }

      if (this.birthday != null && bday == null)
        {
          this.birthday = null;
          this.calendar_event_id = null;
        }
      else if (bday != null)
        {
          this.birthday = bday;
          this.calendar_event_id = calendar_event_id;
        }
    }

  private void _update_notes ()
    {
      this._notes.clear ();

      foreach (var persona in this._persona_set)
        {
          var note_details = persona as NoteDetails;
          if (note_details != null)
            {
              foreach (var n in note_details.notes)
                {
                  this._notes.add (n);
                }
            }
        }

      this.notify_property ("notes");
    }

  private void _set_personas (Set<Persona>? personas,
      Individual? replacement_individual)
    {
      var added = new HashSet<Persona> ();
      var removed = new HashSet<Persona> ();

      /* Determine which Personas have been added. If personas == null, we
       * assume it's an empty set. */
      if (personas != null)
        {
          foreach (var p in personas)
            {
              if (!this._persona_set.contains (p))
                {
                  /* Keep track of how many Personas are users */
                  if (p.is_user)
                    this._persona_user_count++;

                  added.add (p);

                  this._persona_set.add (p);
                  this._connect_to_persona (p);

                  /* Increment the Persona count for this PersonaStore */
                  var store = p.store;
                  var num_from_store = this._stores.get (store);
                  if (num_from_store == 0)
                    {
                      this._stores.set (store, num_from_store + 1);
                    }
                  else
                    {
                      this._stores.set (store, 1);

                      store.removed.connect (this._store_removed_cb);
                      store.personas_changed.connect (
                          this._store_personas_changed_cb);
                    }
                }
            }
        }

      /* Determine which Personas have been removed */
      var iter = this._persona_set.iterator ();
      while (iter.next ())
        {
          var p = iter.get ();

          if (personas == null || !personas.contains (p))
            {
              /* Keep track of how many Personas are users */
              if (p.is_user)
                this._persona_user_count--;

              removed.add (p);

              /* Decrement the Persona count for this PersonaStore */
              var store = p.store;
              var num_from_store = this._stores.get (store);
              if (num_from_store > 1)
                {
                  this._stores.set (store, num_from_store - 1);
                }
              else
                {
                  store.removed.disconnect (this._store_removed_cb);
                  store.personas_changed.disconnect (
                      this._store_personas_changed_cb);

                  this._stores.unset (store);
                }

              this._disconnect_from_persona (p);
              iter.remove ();
            }
        }

      this._emit_personas_changed (added, removed);

      /* Update this.is_user */
      var new_is_user = (this._persona_user_count > 0) ? true : false;
      if (new_is_user != this.is_user)
        this.is_user = new_is_user;

      /* If all the Personas have been removed, remove the Individual */
      if (this._persona_set.size < 1)
        {
          this.removed (replacement_individual);
          return;
        }

      /* Update the ID. We choose the most interesting Persona in the
       * Individual and hash their UID. This is guaranteed to be globally
       * unique, and may not change (for one of the two Individuals) if we link
       * two Individuals together, which is nice though we can't rely on this
       * behaviour.
       *
       * This method of constructing an ID ensures that it'll be unique and
       * stable for a given Individual once the IndividualAggregator reaches
       * a quiescent state after startup. It guarantees that the ID will be
       * the same every time folks is used, until the Individual is linked
       * or unlinked to another Individual.
       *
       * We choose the most interesting Persona by ranking all the Personas
       * in the Individual by:
       *  1. store.is-writeable
       *  2. store.trust-level
       *  3. store.id (alphabetically)
       *
       * Note that this heuristic shouldn't be changed without careful thought,
       * since stored references to IDs may be broken by the change.
       */
      if (this._persona_set.size > 0)
        {
          Persona? chosen_persona = null;

          foreach (var persona in this._persona_set)
            {
              if (chosen_persona == null ||
                  (chosen_persona.store.is_writeable == false &&
                      persona.store.is_writeable == true) ||
                  (chosen_persona.store.is_writeable ==
                          persona.store.is_writeable &&
                      chosen_persona.store.trust_level >
                          persona.store.trust_level) ||
                  (chosen_persona.store.is_writeable ==
                          persona.store.is_writeable &&
                      chosen_persona.store.trust_level ==
                          persona.store.trust_level &&
                      chosen_persona.store.id > persona.store.id)
                 )
               {
                 chosen_persona = persona;
               }
            }

          // Hash the chosen persona's UID
          this.id = Checksum.compute_for_string (ChecksumType.SHA1,
              chosen_persona.uid);
        }

      /* Update our aggregated fields and notify the changes */
      this._update_fields ();
    }

  internal void replace (Individual replacement_individual)
    {
      this._set_personas (null, replacement_individual);
    }
}
