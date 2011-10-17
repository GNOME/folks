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
using TelepathyGLib;
using Folks;

/**
 * A persona subclass which represents a single instant messaging contact from
 * Telepathy.
 */
public class Tpf.Persona : Folks.Persona,
    AliasDetails,
    AvatarDetails,
    BirthdayDetails,
    EmailDetails,
    FavouriteDetails,
    GroupDetails,
    ImDetails,
    NameDetails,
    PhoneDetails,
    PresenceDetails,
    UrlDetails
{
  private HashSet<string> _groups;
  private Set<string> _groups_ro;
  private bool _is_favourite;
  private string _alias; /* must never be null */
  private string _full_name; /* must never be null */
  private HashMultiMap<string, ImFieldDetails> _im_addresses;
  private const string[] _linkable_properties = { "im-addresses" };
  private const string[] _always_writeable_properties =
    {
      "alias",
      "is-favourite",
      "groups"
    };
  private string[] _writeable_properties = null;

  /* Whether we've finished being constructed; this is used to prevent
   * unnecessary trips to the Telepathy service to tell it about properties
   * being set which are actually just being set from data it's just given us.
   */
  private bool _is_constructed = false;

  /**
   * Whether the Persona is in the user's contact list.
   *
   * This will be true for most {@link Folks.Persona}s, but may not be true for
   * personas where {@link Folks.Persona.is_user} is true. If it's false in
   * this case, it means that the persona has been retrieved from the Telepathy
   * connection, but has not been added to the user's contact list.
   *
   * @since 0.3.5
   */
  public bool is_in_contact_list { get; set; }

  private LoadableIcon? _avatar = null;

  /**
   * An avatar for the Persona.
   *
   * See {@link Folks.AvatarDetails.avatar}.
   *
   * @since 0.6.0
   */
  [CCode (notify = false)]
  public LoadableIcon? avatar
    {
      get { return this._avatar; }
      set { this.change_avatar.begin (value); } /* not writeable */
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.4
   */
  [CCode (notify = false)]
  public StructuredName? structured_name
    {
      get { return null; }
      set { this.change_structured_name.begin (value); } /* not writeable */
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.4
   */
  [CCode (notify = false)]
  public string full_name
    {
      get { return this._full_name; }
      set { this.change_full_name.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.4
   */
  public async void change_full_name (string full_name) throws PropertyError
    {
      var tpf_store = this.store as Tpf.PersonaStore;

      if (full_name == this._full_name)
        return;

      if (this._is_constructed)
        {
          try
            {
              yield tpf_store.change_user_full_name (this, full_name);
            }
          catch (PersonaStoreError.INVALID_ARGUMENT e1)
            {
              throw new PropertyError.NOT_WRITEABLE (e1.message);
            }
          catch (PersonaStoreError.STORE_OFFLINE e2)
            {
              throw new PropertyError.UNKNOWN_ERROR (e2.message);
            }
          catch (PersonaStoreError e3)
            {
              throw new PropertyError.UNKNOWN_ERROR (e3.message);
            }
        }

      /* the change will be notified when we receive changes to
       * contact.contact_info */
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.4
   */
  [CCode (notify = false)]
  public string nickname
    {
      get { return ""; }
      set { this.change_nickname.begin (value); } /* not writeable */
    }

  /**
   * {@inheritDoc}
   *
   * ContactInfo has no equivalent field, so this is unsupported.
   *
   * @since 0.6.4
   */
  [CCode (notify = false)]
  public string? calendar_event_id
    {
      get { return null; } /* unsupported */
      set { this.change_calendar_event_id.begin (value); } /* not writeable */
    }

  private DateTime? _birthday = null;
  /**
   * {@inheritDoc}
   *
   * @since 0.6.4
   */
  [CCode (notify = false)]
  public DateTime? birthday
    {
      get { return this._birthday; }
      set { this.change_birthday.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.4
   */
  public async void change_birthday (DateTime? birthday) throws PropertyError
    {
      var tpf_store = this.store as Tpf.PersonaStore;

      if (birthday != null && this._birthday != null &&
          birthday.equal (this._birthday))
        {
          return;
        }

      if (this._is_constructed)
        {
          try
            {
              yield tpf_store.change_user_birthday (this, birthday);
            }
          catch (PersonaStoreError.INVALID_ARGUMENT e1)
            {
              throw new PropertyError.NOT_WRITEABLE (e1.message);
            }
          catch (PersonaStoreError.STORE_OFFLINE e2)
            {
              throw new PropertyError.UNKNOWN_ERROR (e2.message);
            }
          catch (PersonaStoreError e3)
            {
              throw new PropertyError.UNKNOWN_ERROR (e3.message);
            }
        }

      /* the change will be notified when we receive changes to
       * contact.contact_info */
    }

  /**
   * The Persona's presence type.
   *
   * See {@link Folks.PresenceDetails.presence_type}.
   */
  public Folks.PresenceType presence_type { get; private set; }

  /**
   * The Persona's presence status.
   *
   * See {@link Folks.PresenceDetails.presence_status}.
   *
   * @since 0.6.0
   */
  public string presence_status { get; private set; }

  /**
   * The Persona's presence message.
   *
   * See {@link Folks.PresenceDetails.presence_message}.
   */
  public string presence_message { get; private set; }

  /**
   * The names of the Persona's linkable properties.
   *
   * See {@link Folks.Persona.linkable_properties}.
   */
  public override string[] linkable_properties
    {
      get { return this._linkable_properties; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  public override string[] writeable_properties
    {
      get
        {
          if (this.is_user)
            return this._writeable_properties;

          return this._always_writeable_properties;
        }
    }

  /**
   * An alias for the Persona.
   *
   * See {@link Folks.AliasDetails.alias}.
   */
  [CCode (notify = false)]
  public string alias
    {
      get { return this._alias; }
      set { this.change_alias.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_alias (string alias) throws PropertyError
    {
      if (this._alias == alias)
        {
          return;
        }

      if (this._is_constructed)
        {
          yield ((Tpf.PersonaStore) this.store).change_alias (this, alias);
        }

      this._alias = alias;
      this.notify_property ("alias");
    }

  /**
   * Whether this Persona is a user-defined favourite.
   *
   * See {@link Folks.FavouriteDetails.is_favourite}.
   */
  [CCode (notify = false)]
  public bool is_favourite
    {
      get { return this._is_favourite; }
      set { this.change_is_favourite.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_is_favourite (bool is_favourite) throws PropertyError
    {
      if (this._is_favourite == is_favourite)
        {
          return;
        }

      if (this._is_constructed)
        {
          yield ((Tpf.PersonaStore) this.store).change_is_favourite (this,
              is_favourite);
        }

      this._is_favourite = is_favourite;
      this.notify_property ("is-favourite");
    }

  private HashSet<EmailFieldDetails> _email_addresses;
  private Set<EmailFieldDetails> _email_addresses_ro;

  /**
   * {@inheritDoc}
   *
   * @since 0.6.4
   */
  [CCode (notify = false)]
  public Set<EmailFieldDetails> email_addresses
    {
      get { return this._email_addresses_ro; }
      set { this.change_email_addresses.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.4
   */
  public async void change_email_addresses (
      Set<EmailFieldDetails> email_addresses) throws PropertyError
    {
      yield this._change_details<EmailFieldDetails> (email_addresses,
          this._email_addresses, "email");
    }

  /**
   * A mapping of IM protocol to an (unordered) set of IM addresses.
   *
   * See {@link Folks.ImDetails.im_addresses}.
   */
  [CCode (notify = false)]
  public MultiMap<string, ImFieldDetails> im_addresses
    {
      get { return this._im_addresses; }
      set { this.change_im_addresses.begin (value); }
    }

  /**
   * A mapping of group ID to whether the contact is a member.
   *
   * See {@link Folks.GroupDetails.groups}.
   */
  [CCode (notify = false)]
  public Set<string> groups
    {
      get { return this._groups_ro; }
      set { this.change_groups.begin (value); }
    }

  /**
   * Add or remove the Persona from the specified group.
   *
   * See {@link Folks.GroupDetails.change_group}.
   */
  public async void change_group (string group, bool is_member)
    {
      if (this._change_group (group, is_member))
        {
          Tpf.PersonaStore store = (Tpf.PersonaStore) this.store;
          yield store._change_group_membership (this, group, is_member);
        }
    }

  private bool _change_group (string group, bool is_member)
    {
      var changed = false;

      if (is_member)
        {
          if (!this._groups.contains (group))
            {
              this._groups.add (group);
              changed = true;
            }
        }
      else
        changed = this._groups.remove (group);

      if (changed == true)
        this.group_changed (group, is_member);

      return changed;
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_groups (Set<string> groups) throws PropertyError
    {
      Tpf.PersonaStore store = (Tpf.PersonaStore) this.store;

      foreach (var group1 in groups)
        {
          if (this._groups.contains (group1) == false)
            yield store._change_group_membership (this, group1, true);
        }

      foreach (var group2 in this._groups)
        {
          if (groups.contains (group2) == false)
            yield store._change_group_membership (this, group2, false);
        }

      this.notify_property ("groups");
    }

  /**
   * The Telepathy contact represented by this persona.
   *
   * Note that this may be `null` if the {@link PersonaStore} providing this
   * {@link Persona} isn't currently available (e.g. due to not being connected
   * to the network). In this case, most other properties of the {@link Persona}
   * are being retrieved from a cache and may not be current (though there's no
   * way to tell this).
   */
  public Contact? contact { get; construct; }

  private HashSet<PhoneFieldDetails> _phone_numbers;
  private Set<PhoneFieldDetails> _phone_numbers_ro;

  /**
   * {@inheritDoc}
   *
   * @since 0.6.4
   */
  [CCode (notify = false)]
  public Set<PhoneFieldDetails> phone_numbers
    {
      get { return this._phone_numbers_ro; }
      set { this.change_phone_numbers.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.4
   */
  public async void change_phone_numbers (
      Set<PhoneFieldDetails> phone_numbers) throws PropertyError
    {
      yield this._change_details<PhoneFieldDetails> (phone_numbers,
          this._phone_numbers, "tel");
    }

  private HashSet<UrlFieldDetails> _urls;
  private Set<UrlFieldDetails> _urls_ro;

  /**
   * {@inheritDoc}
   *
   * @since 0.6.4
   */
  [CCode (notify = false)]
  public Set<UrlFieldDetails> urls
    {
      get { return this._urls_ro; }
      set { this.change_urls.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.4
   */
  public async void change_urls (Set<UrlFieldDetails> urls) throws PropertyError
    {
      yield this._change_details<UrlFieldDetails> (urls,
          this._urls, "url");
    }

  private async void _change_details<T> (
      Set<AbstractFieldDetails<string>> details,
      Set<AbstractFieldDetails<string>> member_set,
      string field_name)
        throws PropertyError
    {
      var tpf_store = this.store as Tpf.PersonaStore;

      if (Folks.Internal.equal_sets<T> (details, member_set))
        {
          return;
        }

      if (this._is_constructed)
        {
          try
            {
              yield tpf_store._change_user_details (this, details, field_name);
            }
          catch (PersonaStoreError.INVALID_ARGUMENT e1)
            {
              throw new PropertyError.NOT_WRITEABLE (e1.message);
            }
          catch (PersonaStoreError.STORE_OFFLINE e2)
            {
              throw new PropertyError.UNKNOWN_ERROR (e2.message);
            }
          catch (PersonaStoreError e3)
            {
              throw new PropertyError.UNKNOWN_ERROR (e3.message);
            }
        }

      /* the change will be notified when we receive changes to
       * contact.contact_info */
    }

  /**
   * Create a new persona.
   *
   * Create a new persona for the {@link PersonaStore} `store`, representing
   * the Telepathy contact given by `contact`.
   *
   * @param contact the Telepathy contact being represented by the persona
   * @param store the persona store to place the persona in
   */
  public Persona (Contact contact, PersonaStore store)
    {
      unowned string id = contact.get_identifier ();
      var connection = contact.connection;
      var account = this._account_for_connection (connection);
      var uid = this.build_uid (store.type_id, store.id, id);

      Object (alias: contact.get_alias (),
              contact: contact,
              display_id: id,
              /* FIXME: This IID format should be moved out to the ImDetails
               * interface along with the code in
               * Kf.Persona.linkable_property_to_links(), but that depends on
               * bgo#624842 being fixed. */
              iid: account.get_protocol () + ":" + id,
              uid: uid,
              store: store,
              is_user: contact.handle == connection.self_handle);


      this._full_name = "";

      contact.notify["alias"].connect ((s, p) =>
          {
            /* Tp guarantees that aliases are always non-null. */
            assert (this.contact.alias != null);

            if (this._alias != this.contact.alias)
              {
                this._alias = this.contact.alias;
                this.notify_property ("alias");
              }
          });

      debug ("Creating new Tpf.Persona '%s' for service-specific UID '%s': %p",
          uid, id, this);
      this._is_constructed = true;

      /* Set our single IM address */
      this._im_addresses = new HashMultiMap<string, ImFieldDetails> (
          null, null,
          (GLib.HashFunc) ImFieldDetails.hash,
          (GLib.EqualFunc) ImFieldDetails.equal);

      try
        {
          var im_addr = ImDetails.normalise_im_address (id,
              account.get_protocol ());
          var im_fd = new ImFieldDetails (im_addr);
          this._im_addresses.set (account.get_protocol (), im_fd);
        }
      catch (ImDetailsError e)
        {
          /* This should never happen…but if it does, warn of it and continue */
          warning (e.message);
        }

      /* Groups */
      this._groups = new HashSet<string> ();
      this._groups_ro = this._groups.read_only_view;

      this._email_addresses = new HashSet<EmailFieldDetails> (
          (GLib.HashFunc) EmailFieldDetails.hash,
          (GLib.EqualFunc) EmailFieldDetails.equal);
      this._email_addresses_ro = this._email_addresses.read_only_view;
      this._phone_numbers = new HashSet<PhoneFieldDetails> (
          (GLib.HashFunc) PhoneFieldDetails.hash,
          (GLib.EqualFunc) PhoneFieldDetails.equal);
      this._phone_numbers_ro = this._phone_numbers.read_only_view;
      this._urls = new HashSet<UrlFieldDetails> (
          (GLib.HashFunc) UrlFieldDetails.hash,
          (GLib.EqualFunc) UrlFieldDetails.equal);
      this._urls_ro = this._urls.read_only_view;

      contact.notify["avatar-file"].connect ((s, p) =>
        {
          this._contact_notify_avatar ();
        });
      this._contact_notify_avatar ();

      contact.notify["presence-message"].connect ((s, p) =>
        {
          this._contact_notify_presence_message ();
        });
      contact.notify["presence-type"].connect ((s, p) =>
        {
          this._contact_notify_presence_type ();
        });
      contact.notify["presence-status"].connect ((s, p) =>
        {
          this._contact_notify_presence_status ();
        });
      this._contact_notify_presence_message ();
      this._contact_notify_presence_type ();
      this._contact_notify_presence_status ();

      contact.notify["contact-info"].connect ((s, p) =>
        {
          this._contact_notify_contact_info ();
        });
      this._contact_notify_contact_info ();

      ((Tpf.PersonaStore) this.store).group_members_changed.connect (
          (s, group, added, removed) =>
            {
              if (added.find (this) != null)
                this._change_group (group, true);

              if (removed.find (this) != null)
                this._change_group (group, false);
            });

      ((Tpf.PersonaStore) this.store).group_removed.connect (
          (s, group, error) =>
            {
              /* FIXME: Can't use
               * !(error is TelepathyGLib.DBusError.OBJECT_REMOVED) because the
               * GIR bindings don't annotate errors */
              if (error != null &&
                  (error.domain != TelepathyGLib.dbus_errors_quark () ||
                   error.code != TelepathyGLib.DBusError.OBJECT_REMOVED))
                {
                  debug ("Group invalidated: %s", error.message);
                  this._change_group (group, false);
                }
            });

      if (this.is_user)
        {
          ((Tpf.PersonaStore) this.store).notify["supported-fields"].connect (
            (s, p) =>
              {
                this._store_notify_supported_fields ();
              });
          this._store_notify_supported_fields ();
        }
    }

  private void _store_notify_supported_fields ()
    {
      var tpf_store = this.store as Tpf.PersonaStore;
      this._writeable_properties = this._always_writeable_properties;

      if ("bday" in tpf_store.supported_fields)
        this._writeable_properties += "birthday";
      if ("email" in tpf_store.supported_fields)
        this._writeable_properties += "email-addresses";
      if ("fn" in tpf_store.supported_fields)
        this._writeable_properties += "full-name";
      if ("tel" in tpf_store.supported_fields)
        this._writeable_properties += "phone-numbers";
      if ("url" in tpf_store.supported_fields)
        this._writeable_properties += "urls";
    }

  private void _contact_notify_contact_info ()
    {
      var new_birthday_str = "";
      var new_full_name = "";
      var new_email_addresses = new HashSet<EmailFieldDetails> (
          (GLib.HashFunc) EmailFieldDetails.hash,
          (GLib.EqualFunc) EmailFieldDetails.equal);
      var new_phone_numbers = new HashSet<PhoneFieldDetails> (
          (GLib.HashFunc) PhoneFieldDetails.hash,
          (GLib.EqualFunc) PhoneFieldDetails.equal);
      var new_urls = new HashSet<UrlFieldDetails> (
          (GLib.HashFunc) UrlFieldDetails.hash,
          (GLib.EqualFunc) UrlFieldDetails.equal);

      var contact_info = this.contact.get_contact_info ();
      foreach (var info in contact_info)
        {
          if (info.field_name == "") {}
          else if (info.field_name == "bday")
            {
              new_birthday_str = info.field_value[0];
            }
          else if (info.field_name == "email")
            {
              foreach (var email_addr in info.field_value)
                {
                  var parameters = this._afd_params_from_strv (info.parameters);
                  var email_fd = new EmailFieldDetails (email_addr, parameters);
                  new_email_addresses.add (email_fd);
                }
            }
          else if (info.field_name == "fn")
            {
              new_full_name = info.field_value[0];
            }
          else if (info.field_name == "tel")
            {
              foreach (var phone_num in info.field_value)
                {
                  var parameters = this._afd_params_from_strv (info.parameters);
                  var phone_fd = new PhoneFieldDetails (phone_num, parameters);
                  new_phone_numbers.add (phone_fd);
                }
            }
          else if (info.field_name == "url")
            {
              foreach (var url in info.field_value)
                {
                  var parameters = this._afd_params_from_strv (info.parameters);
                  var url_fd = new UrlFieldDetails (url, parameters);
                  new_urls.add (url_fd);
                }
            }
        }

      if (new_birthday_str != "")
        {
          var timeval = TimeVal ();
          if (timeval.from_iso8601 (new_birthday_str))
            {
              var d = new DateTime.from_timeval_utc (timeval);
              if (this._birthday == null ||
                  (this._birthday != null &&
                    !this._birthday.equal (d.to_utc ())))
                {
                  this._birthday = d.to_utc ();
                  this.notify_property ("birthday");
                }
            }
          else
            {
              warning ("Failed to parse new birthday string '%s'",
                  new_birthday_str);
            }
        }
      else
        {
          if (this._birthday != null)
            {
              this._birthday = null;
              this.notify_property ("birthday");
            }
        }

      if (!Folks.Internal.equal_sets<EmailFieldDetails> (new_email_addresses,
              this._email_addresses))
        {
          this._email_addresses = new_email_addresses;
          this._email_addresses_ro = new_email_addresses.read_only_view;
          this.notify_property ("email-addresses");
        }

      if (new_full_name != this._full_name)
        {
          this._full_name = new_full_name;
          this.notify_property ("full-name");
        }

      if (!Folks.Internal.equal_sets<PhoneFieldDetails> (new_phone_numbers,
              this._phone_numbers))
        {
          this._phone_numbers = new_phone_numbers;
          this._phone_numbers_ro = new_phone_numbers.read_only_view;
          this.notify_property ("phone-numbers");
        }

      if (!Folks.Internal.equal_sets<UrlFieldDetails> (new_urls, this._urls))
        {
          this._urls = new_urls;
          this._urls_ro = new_urls.read_only_view;
          this.notify_property ("urls");
        }
    }

  private MultiMap<string, string> _afd_params_from_strv (string[] parameters)
    {
      var retval = new HashMultiMap<string, string> ();

      foreach (var entry in parameters)
        {
          var tokens = entry.split ("=", 2);
          if (tokens.length == 2)
            {
              retval.set (tokens[0], tokens[1]);
            }
          else
            {
              warning ("Failed to parse vCard parameter from string '%s'",
                  entry);
            }
        }

      return retval;
    }

  /**
   * Create a new persona for the {@link PersonaStore} `store`, representing
   * a cached contact for which we currently have no Telepathy contact.
   *
   * @param store The persona store to place the persona in.
   * @param uid The cached UID of the persona.
   * @param iid The cached IID of the persona.
   * @param im_address The cached IM address of the persona (excluding
   * protocol).
   * @param protocol The cached protocol of the persona.
   * @param groups The cached set of groups the persona is in.
   * @param is_favourite Whether the persona is a favourite.
   * @param alias The cached alias for the persona.
   * @param is_in_contact_list Whether the persona is in the user's contact
   * list.
   * @param is_user Whether the persona is the user.
   * @param avatar The icon for the persona's cached avatar, or `null` if they
   * have no avatar.
   * @param birthday The date/time of birth of the persona, or `null` if it's
   * unknown.
   * @param full_name The persona's full name, or the empty string if it's
   * unknown.
   * @param email_addresses A set of the persona's e-mail addresses, which may
   * be empty (but may not be `null`).
   * @param phone_numbers A set of the persona's phone numbers, which may be
   * empty (but may not be `null`).
   * @param urls A set of the persona's URLs, which may be empty (but may not be
   * `null`).
   * @return A new {@link Tpf.Persona} representing the cached persona.
   *
   * @since 0.6.0
   */
  internal Persona.from_cache (PersonaStore store, string uid, string iid,
      string im_address, string protocol, HashSet<string> groups,
      bool is_favourite, string alias, bool is_in_contact_list, bool is_user,
      LoadableIcon? avatar, DateTime? birthday, string full_name,
      HashSet<EmailFieldDetails> email_addresses,
      HashSet<PhoneFieldDetails> phone_numbers, HashSet<UrlFieldDetails> urls)
    {
      Object (contact: null,
              display_id: im_address,
              iid: iid,
              uid: uid,
              store: store,
              is_user: is_user);

      debug ("Creating new Tpf.Persona '%s' from cache: %p", uid, this);

      // IM addresses
      this._im_addresses = new HashMultiMap<string, ImFieldDetails> (null, null,
          (GLib.HashFunc) ImFieldDetails.hash,
          (GLib.EqualFunc) ImFieldDetails.equal);

      var im_fd = new ImFieldDetails (im_address);
      this._im_addresses.set (protocol, im_fd);

      // Groups
      this._groups = groups;
      this._groups_ro = this._groups.read_only_view;

      // E-mail addresses
      this._email_addresses = email_addresses;
      this._email_addresses_ro = this._email_addresses.read_only_view;

      // Phone numbers
      this._phone_numbers = phone_numbers;
      this._phone_numbers_ro = this._phone_numbers.read_only_view;

      // URLs
      this._urls = urls;
      this._urls_ro = this._urls.read_only_view;

      // Other properties
      if (alias == null)
        {
          /* Deal with badly-behaved callers */
          alias = "";
        }

      if (full_name == null)
        {
          /* Deal with badly-behaved callers */
          full_name = "";
        }

      this._alias = alias;
      this._is_favourite = is_favourite;
      this.is_in_contact_list = is_in_contact_list;
      this._avatar = avatar;
      this._birthday = birthday;
      this._full_name = full_name;

      // Make the persona appear offline
      this.presence_type = PresenceType.OFFLINE;
      this.presence_message = "";
    }

  ~Persona ()
    {
      debug ("Destroying Tpf.Persona '%s': %p", this.uid, this);
    }

  private static Account? _account_for_connection (Connection conn)
    {
      var manager = AccountManager.dup ();
      var accounts = manager.get_valid_accounts ();

      Account account_found = null;
      accounts.foreach ((l) =>
        {
          unowned Account account = (Account) l;
          if (account.connection == conn)
            {
              account_found = account;
              return;
            }
        });

      return account_found;
    }

  private void _contact_notify_presence_message ()
    {
      this.presence_message = this.contact.get_presence_message ();
    }

  private void _contact_notify_presence_type ()
    {
      this.presence_type = Tpf.Persona._folks_presence_type_from_tp (
          this.contact.get_presence_type ());
    }

  private void _contact_notify_presence_status ()
    {
      this.presence_status = this.contact.get_presence_status ();
    }

  private static PresenceType _folks_presence_type_from_tp (
      TelepathyGLib.ConnectionPresenceType type)
    {
      switch (type)
        {
          case TelepathyGLib.ConnectionPresenceType.AVAILABLE:
            return PresenceType.AVAILABLE;
          case TelepathyGLib.ConnectionPresenceType.AWAY:
            return PresenceType.AWAY;
          case TelepathyGLib.ConnectionPresenceType.BUSY:
            return PresenceType.BUSY;
          case TelepathyGLib.ConnectionPresenceType.ERROR:
            return PresenceType.ERROR;
          case TelepathyGLib.ConnectionPresenceType.EXTENDED_AWAY:
            return PresenceType.EXTENDED_AWAY;
          case TelepathyGLib.ConnectionPresenceType.HIDDEN:
            return PresenceType.HIDDEN;
          case TelepathyGLib.ConnectionPresenceType.OFFLINE:
            return PresenceType.OFFLINE;
          case TelepathyGLib.ConnectionPresenceType.UNKNOWN:
            return PresenceType.UNKNOWN;
          case TelepathyGLib.ConnectionPresenceType.UNSET:
            return PresenceType.UNSET;
          default:
            return PresenceType.UNKNOWN;
        }
    }

  private void _contact_notify_avatar ()
    {
      var file = this.contact.avatar_file;
      Icon? icon = null;

      if (file != null)
        icon = new FileIcon (file);

      if (this._avatar == null || icon == null || !this._avatar.equal (icon))
        {
          this._avatar = (LoadableIcon) icon;
          this.notify_property ("avatar");
        }
    }
}
