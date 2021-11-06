/*
 * Copyright (C) 2011 Collabora Ltd.
 * Copyright (C) 2013, 2016 Philip Withnall
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
 *       Marco Barisione <marco.barisione@collabora.co.uk>
 *       Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 */

using E;
using Folks;
using Gee;
using GLib;
using Xml;

/**
 * A persona subclass which represents a single EDS contact.
 *
 * Each {@link Edsf.Persona} instance represents a single EDS {@link E.Contact}.
 * When the contact is modified (either by this folks client, or a different
 * client), the {@link Edsf.Persona} remains the same, but is assigned a new
 * {@link E.Contact}. It then updates its properties from this new contact.
 */
public class Edsf.Persona : Folks.Persona,
    AntiLinkable,
    AvatarDetails,
    BirthdayDetails,
    EmailDetails,
    ExtendedInfo,
    FavouriteDetails,
    GenderDetails,
    GroupDetails,
    ImDetails,
    LocalIdDetails,
    LocationDetails,
    NameDetails,
    NoteDetails,
    PhoneDetails,
    RoleDetails,
    UrlDetails,
    PostalAddressDetails,
    WebServiceDetails
{
  /* The following 4 definitions are used by the tests */
  /**
   * vCard field names for telephone numbers.
   *
   * @since 0.6.0
   */
  public const string[] phone_fields = {
    "assistant_phone", "business_phone", "business_phone_2", "callback_phone",
    "car_phone", "company_phone", "home_phone", "home_phone_2", "isdn_phone",
    "mobile_phone", "other_phone", "primary_phone"
  };
  /**
   * vCard field names for postal addresses.
   *
   * @since 0.6.0
   */
  public const string[] address_fields = {
    "address_home", "address_other", "address_work"
  };
  /**
   * vCard field names for e-mail addresses.
   *
   * @since 0.6.0
   */
  public const string[] email_fields = {
    "email_1", "email_2", "email_3", "email_4"
  };

  /**
   * vCard field names for miscellaneous URIs.
   *
   * @since 0.6.0
   */
  [Version (deprecated = true, deprecated_since = "0.6.3",
      replacement = "Folks.UrlFieldDetails.PARAM_TYPE_BLOG")]
  public const string[] url_properties = {
    "blog_url", "fburl", "homepage_url", "video_url"
  };

  /* Some types of URLs are represented in EDS using custom vCard fields rather
   * than the X-URIS field. Here are mappings between the custom vCard field
   * names which EDS uses, and the TYPE values which folks uses which map to
   * them. */
  internal struct UrlTypeMapping
    {
      unowned string vcard_field_name;
      unowned string folks_type;
    }

  internal const UrlTypeMapping[] _url_properties =
    {
      { "homepage_url", UrlFieldDetails.PARAM_TYPE_HOME_PAGE },
      { "blog_url", UrlFieldDetails.PARAM_TYPE_BLOG },
      { "fburl", "x-free-busy" },
      { "video_url", "x-video" }
    };

  /**
   * Name of folks’ custom parameter indicating automatic fields
   *
   * Folks can create extra fields to improve linking between personas.
   * These fields have a boolean-typed parameter added with this name,
   * and the value ‘TRUE’. This allows clients to detect such fields
   * and (for example) ignore them in the UI.
   *
   * @since 0.9.7
   */
  public const string folks_field_attribute_name = "X-FOLKS-FIELD";

  /**
   * The vCard attribute used to specify a Contact's gender
   *
   * Based on:
   * [[http://tools.ietf.org/html/draft-ietf-vcarddav-vcardrev-22]]
   *
   * Note that the above document is a draft and the gender property
   * is still considered experimental, hence the "X-" prefix in the
   * attribute name. So this might change.
   *
   * @since 0.6.0
   */
  public const string gender_attribute_name = "X-GENDER";

  /**
   * The value used to define the male gender for the
   * X-GENDER vCard property.
   *
   * Based on:
   * [[http://tools.ietf.org/html/draft-ietf-vcarddav-vcardrev-22]]
   *
   * @since 0.6.0
   */
  public const string gender_male = "M";

  /**
   * The value used to define the female gender for the
   * X-GENDER vCard property.
   *
   * Based on:
   * [[http://tools.ietf.org/html/draft-ietf-vcarddav-vcardrev-22]]
   *
   * @since 0.6.0
   */
  public const string gender_female = "F";

  private const string[] _linkable_properties =
    {
      "im-addresses",
      "email-addresses",
      "local-ids",
      "web-service-addresses",
      null /* FIXME: https://bugzilla.gnome.org/show_bug.cgi?id=682698 */
    };

  private static GLib.HashTable<unowned string, E.ContactField>? _im_eds_map = null;

  private E.Contact _contact; /* should be set on construct */

  /**
   * The e-d-s contact represented by this Persona
   */
  public E.Contact contact
    {
      get { return this._contact; }
      construct { this._contact = value; }
    }

  /* NOTE: Other properties support lazy initialisation, but
   * web-service-addresses doesn't as it's a linkable property, so always has to
   * be loaded anyway. */
  private HashMultiMap<string, WebServiceFieldDetails> _web_service_addresses;

  /**
   * {@inheritDoc}
   *
   * This is stored in the X-FOLKS-WEB-SERVICES-IDS vCard field in EDS.
   */
  [CCode (notify = false)]
  public MultiMap<string, WebServiceFieldDetails> web_service_addresses
    {
      get { return this._web_service_addresses; }
      set { this.change_web_service_addresses.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_web_service_addresses (
      MultiMap<string, WebServiceFieldDetails> web_service_addresses)
          throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_web_service_addresses (this,
          web_service_addresses);
    }

  /* NOTE: Other properties support lazy initialisation, but local-ids doesn't
   * as it's a linkable property, so always has to be loaded anyway. */
  private SmallSet<string> _local_ids = new SmallSet<string> ();
  private Set<string> _local_ids_ro;

  /**
   * IDs used to link {@link Edsf.Persona}s.
   *
   * This is stored in the X-FOLKS-CONTACTS-IDS vCard field in EDS.
   */
  [CCode (notify = false)]
  public Set<string> local_ids
    {
      get
        {
          if (this._local_ids.contains (this.iid) == false)
            {
              this._local_ids.add (this.iid);
            }
          return this._local_ids_ro;
        }
      set { this.change_local_ids.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_local_ids (Set<string> local_ids)
      throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_local_ids (this, local_ids);
    }

  private Location? _location = null;
  /**
   * {@inheritDoc}
   *
   * @since 0.9.2
   */
  [CCode (notify = false)]
  public Location? location
    {
      get { return this._location; }
      set { this.change_location.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.2
   */
  public async void change_location (Location? location) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_location (this, location);
    }

  private SmallSet<PostalAddressFieldDetails>? _postal_addresses = null;
  private Set<PostalAddressFieldDetails>? _postal_addresses_ro = null;

  /**
   * The postal addresses of the contact.
   *
   * A list of postal addresses associated to the contact.
   *
   * @since 0.6.0
   */
  [CCode (notify = false)]
  public Set<PostalAddressFieldDetails> postal_addresses
    {
      get
        {
          this._update_addresses (true, false);
          return this._postal_addresses_ro;
        }
      set { this.change_postal_addresses.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_postal_addresses (
      Set<PostalAddressFieldDetails> postal_addresses) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_postal_addresses (this,
          postal_addresses);
    }

  private SmallSet<PhoneFieldDetails>? _phone_numbers = null;
  private Set<PhoneFieldDetails>? _phone_numbers_ro = null;

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  [CCode (notify = false)]
  public Set<PhoneFieldDetails> phone_numbers
    {
      get
        {
          this._update_phones (true, false);
          return this._phone_numbers_ro;
        }
      set { this.change_phone_numbers.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_phone_numbers (
      Set<PhoneFieldDetails> phone_numbers) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_phones (this, phone_numbers);
    }

  private SmallSet<EmailFieldDetails>? _email_addresses =
          new SmallSet<EmailFieldDetails> (
                  AbstractFieldDetails<string>.hash_static,
                  AbstractFieldDetails<string>.equal_static);
  private Set<EmailFieldDetails> _email_addresses_ro;

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
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
   * @since 0.6.2
   */
  public async void change_email_addresses (
      Set<EmailFieldDetails> email_addresses) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_emails (this,
          email_addresses);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.11.0
   */
  public ExtendedFieldDetails? get_extended_field (string name)
    {
      return ((Edsf.PersonaStore) this.store)._get_extended_field (this, name);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.11.0
   */
  public async void change_extended_field (
      string name, ExtendedFieldDetails value) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._change_extended_field (this, name, value);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.11.0
   */
  public async void remove_extended_field (string name) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._remove_extended_field (this, name);
    }

  private SmallSet<NoteFieldDetails>? _notes = null;
  private Set<NoteFieldDetails>? _notes_ro = null;

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  [CCode (notify = false)]
  public Set<NoteFieldDetails> notes
    {
      get
        {
          this._update_notes (true, false);
          return this._notes_ro;
        }
      set { this.change_notes.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_notes (Set<NoteFieldDetails> notes)
      throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_notes (this, notes);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  public override string[] linkable_properties
    {
      get { return Persona._linkable_properties; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  public override string[] writeable_properties
    {
      get { return this.store.always_writeable_properties; }
    }

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
      set { this.change_avatar.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_avatar (LoadableIcon? avatar) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_avatar (this, avatar);
    }

  private StructuredName? _structured_name = null;
  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  [CCode (notify = false)]
  public StructuredName? structured_name
    {
      get { return this._structured_name; }
      set { this.change_structured_name.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_structured_name (StructuredName? structured_name)
      throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_structured_name (this,
          structured_name);
    }

  /**
   * The e-d-s contact uid
   *
   * This is guaranteed to be a non-empty string, unique within the persona
   * store.
   *
   * @since 0.6.0
   */
  public string contact_id { get; construct; }

  private string _full_name = "";
  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
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
   * @since 0.6.2
   */
  public async void change_full_name (string full_name) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_full_name (this, full_name);
    }

  private string _nickname = "";
  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  [CCode (notify = false)]
  public string nickname
    {
      get { return this._nickname; }
      set { this.change_nickname.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_nickname (string nickname) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_nickname (this, nickname);
    }

  private Gender _gender;
  /**
   * {@inheritDoc}
   *
   * This is stored in the {@link Edsf.Persona.gender_attribute_name} vCard
   * field in EDS.
   *
   * @since 0.6.0
   */
  [CCode (notify = false)]
  public Gender gender
    {
      get { return this._gender; }
      set { this.change_gender.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_gender (Gender gender) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_gender (this, gender);
    }

  private SmallSet<UrlFieldDetails>? _urls = null;
  private Set<UrlFieldDetails>? _urls_ro = null;
  /**
   * {@inheritDoc}
   *
   * This is stored in the X-URIS vCard field in EDS.
   *
   * @since 0.6.0
   */
  [CCode (notify = false)]
  public Set<UrlFieldDetails> urls
    {
      get
        {
          this._update_urls (true, false);
          return this._urls_ro;
        }
      set { this.change_urls.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_urls (Set<UrlFieldDetails> urls) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_urls (this, urls);
    }

  /* NOTE: Other properties support lazy initialisation, but im-addresses
   * doesn't as it's a linkable property, so always has to be loaded anyway. */
  private HashMultiMap<string, ImFieldDetails> _im_addresses =
      new HashMultiMap<string, ImFieldDetails> (null, null,
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  [CCode (notify = false)]
  public MultiMap<string, ImFieldDetails> im_addresses
    {
      get { return this._im_addresses; }
      set { this.change_im_addresses.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_im_addresses (
      MultiMap<string, ImFieldDetails> im_addresses) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_im_fds (this, im_addresses);
    }

  private SmallSet<string>? _groups = null;
  private Set<string>? _groups_ro = null;

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  [CCode (notify = false)]
  public Set<string> groups
    {
      get
        {
          this._update_groups (true, false);
          return this._groups_ro;
        }
      set { this.change_groups.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  public async void change_group (string group, bool is_member)
      throws GLib.Error
    {
      /* NOTE: This method specifically accesses this.groups rather than
       * this._groups, so that lazy loading is guaranteed to happen if
       * necessary. */
      /* Nothing to do? */
      if ((is_member == true && this.groups.contains (group) == true) ||
          (is_member == false && this.groups.contains (group) == false))
        {
          return;
        }

      /* Replace the current set of groups with a modified one. */
      var new_groups = SmallSet<string>.copy (this.groups);

      if (is_member == false)
        {
          new_groups.remove (group);
        }
      else
        {
          new_groups.add (group);
        }

      yield this.change_groups (new_groups);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_groups (Set<string> groups) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_groups (this, groups);
    }

  /**
   * Change the contact's system groups.
   *
   * The system groups are a property exposed by Google Contacts address books,
   * and can include any combination of the following identifier:
   * - "Contacts"
   * - "Family"
   * - "Friends"
   * - "Coworkers"
   *
   * Setting the system groups will also change the group membership to include
   * the localized version of those groups, and may change the value of
   * {@link Edsf.Persona.in_google_personal_group}.
   *
   * Attempting to call this method on a persona belonging to a PersonaStore which
   * is not Google will throw a PropertyError.
   *
   * It's preferred to call this rather than setting {@link Persona.system_groups}
   * directly, as this method gives error notification and will only return once
   * the groups have been written to the relevant backing store (or the
   * operation's failed).
   *
   * @param system_groups the complete set of system group ids the contact should be a member of
   * @throws PropertyError if setting the groups failed
   * @since 0.9.0
   */
  public async void change_system_groups (Set<string> system_groups) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_system_groups (this, system_groups);
    }

  private const string GOOGLE_PERSONAL_GROUP_NAME = "Contacts";

  /**
   * Change whether this contact belongs to the personal group or not.
   *
   * The personal contact group is a concept that exists only in Google
   * address books. Other backends will throw a PropertyError.
   *
   * It's preferred to call this rather than setting {@link Persona.in_google_personal_group}
   * directly, as this method gives error notification and will only return once
   * the membership has been written to the relevant backing store (or the
   * operation's failed).
   *
   * @param in_personal Whether to add or remove the personal group membership
   * @throws PropertyError if the address book is not Google, or if setting the property failed
   * @since 0.9.0
   */
  public async void change_in_google_personal_group (bool in_personal) throws PropertyError
    {
      if (in_personal == this._in_google_personal_group)
        {
          return;
        }

      var new_system_groups = SmallSet<string>.copy (this._system_groups);

      if (in_personal)
        {
          new_system_groups.add (GOOGLE_PERSONAL_GROUP_NAME);
        }
      else
        {
          new_system_groups.remove (GOOGLE_PERSONAL_GROUP_NAME);
        }

      yield ((Edsf.PersonaStore) this.store)._set_system_groups (this, new_system_groups);
    }

  /**
   * {@inheritDoc}
   *
   * e-d-s has no equivalent field, so this is unsupported.
   *
   * @since 0.6.2
   */
  [CCode (notify = false)]
  public string? calendar_event_id
    {
      get { return null; } /* unsupported */
      set { this.change_calendar_event_id.begin (value); } /* not writeable */
    }

  /* We cache the timezone we use for converting birthdays to UTC since creating
   * it requires mmapping /etc/localtime, which means lots of syscalls. */
  private static TimeZone _local_time_zone = new TimeZone.local ();

  private DateTime? _birthday = null;
  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
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
   * @since 0.6.2
   */
  public async void change_birthday (DateTime? bday)
      throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_birthday (this,
          bday);
    }

  private SmallSet<RoleFieldDetails>? _roles = null;
  private Set<RoleFieldDetails>? _roles_ro = null;

  /**
   * {@inheritDoc}
   *
   * This is stored in the X-ROLES vCard field in EDS.
   *
   * @since 0.6.2
   */
  [CCode (notify = false)]
  public Set<RoleFieldDetails> roles
    {
      get
        {
          this._update_roles (true, false);
          return this._roles_ro;
        }
      set { this.change_roles.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_roles (Set<RoleFieldDetails> roles)
      throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_roles (this, roles);
    }

  private bool _is_favourite = false;

  /**
   * Whether this contact is a user-defined favourite.
   *
   * This is stored in the X-FOLKS-FAVOURITE vCard field in EDS.
   *
   * @since 0.6.5
   */
  [CCode (notify = false)]
  public bool is_favourite
      {
        get
          {
            this._update_groups (true, false); /* also checks for favourites */
            return this._is_favourite;
          }
        set { this.change_is_favourite.begin (value); }
      }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.5
   */
  public async void change_is_favourite (bool is_favourite) throws PropertyError
    {
      if (this._is_favourite == is_favourite)
        {
          return;
        }

      yield ((Edsf.PersonaStore) this.store)._set_is_favourite (this,
          is_favourite);
    }

  private SmallSet<string> _anti_links;
  private Set<string> _anti_links_ro;

  /**
   * {@inheritDoc}
   *
   * @since 0.7.3
   */
  [CCode (notify = false)]
  public Set<string> anti_links
    {
      get { return this._anti_links_ro; }
      set { this.change_anti_links.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.7.3
   */
  public async void change_anti_links (Set<string> anti_links)
      throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_anti_links (this, anti_links);
    }

  private SmallSet<string>? _system_groups = null;
  private Set<string>? _system_groups_ro = null;
  private bool _in_google_personal_group;

  /**
   * The complete set of system group identifiers the contact belongs to.
   * See {@link Persona.change_system_groups} for details.
   *
   * This is stored in the X-GOOGLE-SYSTEM-GROUP-IDS vCard field in EDS.
   *
   * @since 0.9.0
   */
  [CCode (notify = false)]
  public Set<string>? system_groups
    {
      get
        {
          this._update_groups (true);
          return this._system_groups_ro;
        }

      set { this.change_system_groups.begin (value); }
    }

  /**
   * Whether this contact is in the “My Contacts” section of the user’s address
   * book, rather than the “Other” section.
   *
   * @since 0.7.3
   */
  [CCode (notify = false)]
  public bool in_google_personal_group
    {
      get
        {
          this._update_groups (true); /* also checks for the personal group */
          return this._in_google_personal_group;
        }

      set { this.change_in_google_personal_group.begin (value); }
    }

  /**
   * Build a IID.
   *
   * This requires the UID field of the contact to be set to a non-empty value
   * already; if not, `null` will be returned.
   *
   * @param store_id the {@link PersonaStore.id}
   * @param contact the Contact, which must have a UID field set
   * @return a valid IID, or `null` if none could be constructed
   *
   * @since 0.6.0
   */
  internal static string? build_iid_from_contact (string store_id,
      E.Contact contact)
    {
      unowned var contact_id = contact.get_const<string>(E.ContactField.UID);

      /* If the contact has no UID, then we cannot support it. Callers must
       * this first. */
      if (contact_id == null || contact_id == "")
          return null;

      return Edsf.Persona.build_iid (store_id, contact_id);
    }

  /**
   * Build a IID.
   *
   * @param store_id the {@link PersonaStore.id}, which must be non-empty
   * @param contact_id the ID belonging to the contact, which must be non-empty
   * @return a valid IID
   *
   * @since 0.6.0
   */
  internal static string build_iid (string store_id, string contact_id)
      requires (store_id != "")
      requires (contact_id != "")
    {
      return "%s:%s".printf (store_id, contact_id);
    }


  /**
   * Create a new persona.
   *
   * Create a new persona for the {@link PersonaStore} ``store``, representing
   * the EDS contact given by ``contact``.
   *
   * @param store the store which will contain the persona
   * @param contact the EDS contact being represented by the persona
   *
   * @since 0.6.0
   */
  public Persona (PersonaStore store, E.Contact contact)
    {
      unowned var _contact_id = contact.get_const<string>(E.ContactField.UID);
      assert (_contact_id != null && _contact_id != "");
      unowned var contact_id = (!) _contact_id;

      var uid = Folks.Persona.build_uid (BACKEND_NAME, store.id, contact_id);
      var iid = Edsf.Persona.build_iid (store.id, contact_id);
      var is_user = BookClient.is_self (contact);

      /* Use the IID as the display ID since no other suitable identifier is
       * available which we can guarantee is unique within the store. */
      Object (display_id: iid,
              uid: uid,
              iid: iid,
              store: store,
              is_user: is_user,
              contact_id: contact_id,
              contact: contact);
    }

  construct
    {
      debug ("Creating new Edsf.Persona with IID '%s'", this.iid);

      this._gender = Gender.UNSPECIFIED;
      this._phone_numbers = new SmallSet<PhoneFieldDetails> (
           AbstractFieldDetails<string>.hash_static,
           AbstractFieldDetails<string>.equal_static);
      this._phone_numbers_ro = this._phone_numbers.read_only_view;
      this._email_addresses = new SmallSet<EmailFieldDetails> (
           AbstractFieldDetails<string>.hash_static,
           AbstractFieldDetails<string>.equal_static);
      this._email_addresses_ro = this._email_addresses.read_only_view;
      this._notes = new SmallSet<NoteFieldDetails> (
           AbstractFieldDetails<string>.hash_static,
           AbstractFieldDetails<string>.equal_static);
      this._notes_ro = this._notes.read_only_view;
      this._urls = new SmallSet<UrlFieldDetails> (
           AbstractFieldDetails<string>.hash_static,
           AbstractFieldDetails<string>.equal_static);
      this._urls_ro = this._urls.read_only_view;
      this._postal_addresses = new SmallSet<PostalAddressFieldDetails> (
           AbstractFieldDetails<PostalAddress>.hash_static,
           AbstractFieldDetails<PostalAddress>.equal_static);
      this._postal_addresses_ro = this._postal_addresses.read_only_view;
      this._local_ids = new SmallSet<string> ();
      this._local_ids_ro = this._local_ids.read_only_view;
      this._location = null;
      this._web_service_addresses =
        new HashMultiMap<string, WebServiceFieldDetails> (
          null, null, AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);
      this._groups = new SmallSet<string> ();
      this._groups_ro = this._groups.read_only_view;
      this._roles = new SmallSet<RoleFieldDetails> (
           AbstractFieldDetails<Role>.hash_static,
           AbstractFieldDetails<Role>.equal_static);
      this._roles_ro = this._roles.read_only_view;
      this._anti_links = new SmallSet<string> ();
      this._anti_links_ro = this._anti_links.read_only_view;

      this._update (this._contact);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  public override void linkable_property_to_links (string prop_name,
      Folks.Persona.LinkablePropertyCallback callback)
    {
      if (prop_name == "im-addresses")
        {
          var iter = this._im_addresses.map_iterator ();

          while (iter.next ())
            callback (iter.get_key () + ":" + iter.get_value ().value);
        }
      else if (prop_name == "local-ids")
        {
          /* Note: we need to use this.local_ids and not this._local_ids,
           * otherwise this can have a different  behaviour depending
           * on the state of the current Persona depending on whether
           * this.local_ids was called before or not. */
          foreach (var id in this.local_ids)
            {
              callback (id);
            }
        }
      else if (prop_name == "web-service-addresses")
        {
          var iter = this.web_service_addresses.map_iterator ();

          while (iter.next ())
            callback (iter.get_key () + ":" + iter.get_value ().value);
        }
      else if (prop_name == "email-addresses")
        {
          foreach (var email in this._email_addresses)
              callback (email.value);
        }
      else
        {
          /* Chain up */
          base.linkable_property_to_links (prop_name, callback);
        }
    }

  ~Persona ()
    {
      debug ("Destroying Edsf.Persona '%s': %p", this.uid, this);
    }

  /**
   * Update attribs of the persona.
   */
  internal void _update (E.Contact updated_contact)
    {
      this.freeze_notify ();

      /* We get a new E.Contact instance from EDS containing all the updates,
       * so replace our existing contact with it. */
      this._contact = updated_contact;
      this.notify_property ("contact");

      this._update_names ();
      this._update_avatar ();
      this._update_urls (false);
      this._update_phones (false);
      this._update_addresses (false);
      this._update_emails ();

      /* Note: because we assume certain e-mail addresses
       * (@gmail, @msn, etc) to also be IM IDs we /must/
       * update the latter after we've taken care of the former.
       */
      this._update_im_addresses ();

      this._update_groups (false);
      this._update_notes (false);
      this._update_local_ids ();
      this._update_location ();
      this._update_web_services_addresses ();
      this._update_gender ();
      this._update_birthday ();
      this._update_roles (false);
      this._update_favourite ();
      this._update_anti_links ();

      this.thaw_notify ();
    }

  private void _update_params (AbstractFieldDetails details,
      E.VCardAttribute attr)
    {
      foreach (unowned E.VCardAttributeParam param in attr.get_params ())
        {
          string param_name = param.get_name ().down ();
          foreach (unowned string param_value in param.get_values ())
            {
              if (param_name == AbstractFieldDetails.PARAM_TYPE)
                {
                  details.add_parameter (param_name, param_value.down ());
                }
              else
                {
                  details.add_parameter (param_name, param_value);
                }
            }
        }
    }

  private void _update_gender ()
    {
      var gender = Gender.UNSPECIFIED;
      unowned E.VCardAttribute gender_attr =
          this.contact.get_attribute (Edsf.Persona.gender_attribute_name);

      if (gender_attr != null)
        {
          unowned var val = get_vcard_attr_value ((!) gender_attr);
          if (val != null)
            {
              switch (((!) val).up ())
                {
                  case Edsf.Persona.gender_male:
                    gender = Gender.MALE;
                    break;
                  case Edsf.Persona.gender_female:
                    gender = Gender.FEMALE;
                    break;
                  default:
                    /* Unspecified, as above */
                    break;
                }
            }
        }

      if (this._gender != gender)
        {
          this._gender = gender;
          this.notify_property ("gender");
        }
    }

  private void _update_birthday ()
    {
      var _bday = this._get_property<E.ContactDate> ("birth_date");

      if (_bday != null)
        {
          unowned var bday = (!) _bday;

          /* Since e-d-s stores birthdays as a plain date, we take the
           * given date in local time and convert it to UTC as mandated
           * by the BirthdayDetails interface.
           * We cache the timezone since creating it requires mmapping
           * /etc/localtime, which means lots of syscalls. */
          var d = new DateTime (Persona._local_time_zone,
              (int) bday.year, (int) bday.month, (int) bday.day, 0, 0, 0.0);

          /* d might be null if their birthday in e-d-s is something that
           * doesn't make sense, like 31st February. If so, ignore it. */
          if (d != null && (this._birthday == null ||
              (this._birthday != null &&
                  !((!) this._birthday).equal (d.to_utc ()))))
            {
              this._birthday = d.to_utc ();
              this.notify_property ("birthday");
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
    }

  private void _update_roles (bool create_if_not_exist, bool emit_notification = true)
    {
      /* See the comments in Folks.Individual about the lazy instantiation
       * strategy for roles. */
      if (this._roles == null && create_if_not_exist == false)
        {
          if (emit_notification)
            {
              this.notify_property ("roles");
            }
          return;
        }
      else if (this._roles == null)
        {
          this._roles = new SmallSet<RoleFieldDetails> (
              AbstractFieldDetails<Role>.hash_static,
              AbstractFieldDetails<Role>.equal_static);
          this._roles_ro = this._roles.read_only_view;
        }

      var new_roles = new SmallSet<RoleFieldDetails> (
          AbstractFieldDetails<Role>.hash_static,
          AbstractFieldDetails<Role>.equal_static);

      var default_role_fd = this._get_default_role ();
      if (default_role_fd != null)
        {
          new_roles.add ((!) default_role_fd);
        }

      unowned E.VCard vcard = (E.VCard) this.contact;
      foreach (unowned E.VCardAttribute attr in vcard.get_attributes ())
        {
          if (attr.get_name () != "X-ROLES")
            continue;

          unowned var val = get_vcard_attr_value (attr);
          if (val == null || (!) val == "")
             {
              continue;
            }

          var role = new Role ("", "");
          role.role = (!) val;
          var role_fd = new RoleFieldDetails (role);

          foreach (unowned E.VCardAttributeParam param in
              attr.get_params ())
            {
              string param_name = param.get_name ().down ();

              if (param_name == "organisation_name")
                {
                  foreach (unowned string param_value in
                      param.get_values ())
                    {
                      role.organisation_name = param_value;
                      break;
                    }
                }
              else if (param_name == "title")
                {
                  foreach (unowned string param_value in
                      param.get_values ())
                    {
                      role.title = param_value;
                      break;
                    }
                }
              else
                {
                  foreach (unowned string param_value in
                      param.get_values ())
                    {
                      role_fd.add_parameter (param_name, param_value);
                    }
                }
            }

            new_roles.add (role_fd);
        }

      if (!Folks.Internal.equal_sets<RoleFieldDetails> (new_roles, this._roles))
        {
          this._roles = new_roles;
          this._roles_ro = new_roles.read_only_view;
          if (emit_notification)
            {
              this.notify_property ("roles");
            }
        }
    }

  private RoleFieldDetails? _get_default_role ()
    {
      RoleFieldDetails? _default_role = null;

      unowned var org = this._get_string_property ("org");
      unowned var org_unit = this._get_string_property ("org_unit");
      unowned var office = this._get_string_property ("office");
      unowned var title = this._get_string_property ("title");
      unowned var role = this._get_string_property ("role");
      unowned var manager = this._get_string_property ("manager");
      unowned var assistant = this._get_string_property ("assistant");

      if (org != null ||
          org_unit != null ||
          office != null ||
          title != null ||
          role != null ||
          manager != null ||
          assistant != null)
        {
          var new_role = new Role (title, org);
          if (role != null && (!) role != "")
            new_role.role = (!) role;

          /* Check if it's non-empty. */
          if (!new_role.is_empty ())
            {
              var default_role = new RoleFieldDetails (new_role);

              if (org_unit != null && org_unit != "")
                default_role.set_parameter ("org_unit", (!) org_unit);

              if (office != null && office != "")
                default_role.set_parameter ("office", (!) office);

              if (manager != null && manager != "")
                default_role.set_parameter ("manager", (!) manager);

              if (assistant != null && manager != "")
                default_role.set_parameter ("assistant", (!) assistant);

              _default_role = default_role;
            }
        }

      return _default_role;
    }

  private void _update_web_services_addresses ()
    {
      var new_services = new HashMultiMap<string, WebServiceFieldDetails> (
          null, null, AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

      unowned E.VCardAttribute services =
          this.contact.get_attribute ("X-FOLKS-WEB-SERVICES-IDS");
      if (services != null)
        {
          foreach (unowned VCardAttributeParam service in ((!) services).get_params ())
            {
              var service_name = service.get_name ().down ();
              foreach (unowned string service_id in service.get_values ())
                {
                  if (service_id == "")
                    {
                      continue;
                    }

                  new_services.set (service_name,
                      new WebServiceFieldDetails (service_id));
                }
            }
        }

      if (!Utils.multi_map_str_afd_equal (new_services,
              this._web_service_addresses))
        {
          this._web_service_addresses = new_services;
          this.notify_property ("web-service-addresses");
        }
    }

  private void _update_emails (bool emit_notification = true)
    {
      var new_email_addresses = new SmallSet<EmailFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

      var attrs = this.contact.get_attributes (E.ContactField.EMAIL);
      foreach (unowned E.VCardAttribute attr in attrs)
        {
          unowned var val = get_vcard_attr_value (attr);
          if (val == null || (!) val == "")
            {
              continue;
            }

          var email_fd = new EmailFieldDetails ((!) val);
          this._update_params (email_fd, attr);
          new_email_addresses.add (email_fd);
        }

      if (!Folks.Internal.equal_sets<EmailFieldDetails> (new_email_addresses,
              this._email_addresses))
        {
          this._email_addresses = new_email_addresses;
          this._email_addresses_ro = new_email_addresses.read_only_view;
          if (emit_notification)
            {
              this.notify_property ("email-addresses");
            }
       }
    }

  private void _update_notes (bool create_if_not_exist, bool emit_notification = true)
    {
      /* See the comments in Folks.Individual about the lazy instantiation
       * strategy for notes. */
      if (this._notes == null && create_if_not_exist == false)
        {
          if (emit_notification)
            {
              this.notify_property ("notes");
            }
          return;
        }
      else if (this._notes == null)
        {
          this._notes = new SmallSet<NoteFieldDetails> (
              AbstractFieldDetails<string>.hash_static,
              AbstractFieldDetails<string>.equal_static);
          this._notes_ro = this._notes.read_only_view;
        }

      var new_notes = new SmallSet<NoteFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

      unowned var n = this._get_string_property ("note");
      if (n != null && n != "")
        {
          var note = new NoteFieldDetails ((!) n);
          new_notes.add (note);
        }

      if (!Folks.Internal.equal_sets<NoteFieldDetails> (new_notes, this._notes))
        {
          this._notes = new_notes;
          this._notes_ro = this._notes.read_only_view;
          if (emit_notification)
            {
              this.notify_property ("notes");
            }
        }
    }

  private void _update_names ()
    {
      unowned var full_name = this._get_string_property ("full_name") ?? "";
      if (this._full_name != full_name)
        {
          this._full_name = full_name;
          this.notify_property ("full-name");
        }

      unowned var nickname = this._get_string_property ("nickname") ?? "";
      if (this._nickname != nickname)
        {
          this._nickname = nickname;
          this.notify_property ("nickname");
        }

      StructuredName? structured_name = null;
      var _cn = this._get_property<E.ContactName> ("name");
      if (_cn != null)
        {
          unowned var cn = (!) _cn;

          unowned string family_name = cn.family;
          unowned string given_name  = cn.given;
          unowned string additional_names = cn.additional;
          unowned string prefixes = cn.prefixes;
          unowned string suffixes = cn.suffixes;
          structured_name = new StructuredName (family_name, given_name,
                                                additional_names, prefixes,
                                                suffixes);
        }

      if (structured_name != null && !((!) structured_name).is_empty ())
        {
          this._structured_name = (!) structured_name;
          this.notify_property ("structured-name");
        }
      else if (this._structured_name != null)
        {
          this._structured_name = null;
          this.notify_property ("structured-name");
        }
    }

  private LoadableIcon? _contact_photo_to_loadable_icon (ContactPhoto? _p)
    {
      if (_p == null)
        {
          return null;
        }

      unowned var p = (!) _p;

      switch (p.type)
        {
          case ContactPhotoType.URI:
            unowned var uri = p.get_uri ();
            if (uri == null)
              {
                return null;
              }

            /* Ignore non-local files, or we could end up downloading huge
             * pictures that we really don’t want. Non-local URI-based contact
             * photos are rare anyway.
             *
             * See: https://bugzilla.gnome.org/show_bug.cgi?id=697695 */
            var scheme = Uri.parse_scheme (uri);
            if (scheme == null || scheme != "file")
              {
                warning ("Ignoring contact photo with URI ‘%s’ because it’s " +
                    "not a local file.", uri);
                return null;
              }

            return new FileIcon (File.new_for_uri ((!) uri));
          case ContactPhotoType.INLINED:
            unowned var data = p.get_inlined ();
            unowned var mime_type = p.get_mime_type ();
            if (data == null || mime_type == null)
              {
                return null;
              }

            var bytes = new Bytes ((!) data);
            return new BytesIcon (bytes);
          default:
            return null;
        }
    }

  private void _update_avatar ()
    {
      var p = this._get_property<E.ContactPhoto> ("photo");

      // Convert the ContactPhoto to a LoadableIcon and store or update it.
      var new_avatar = this._contact_photo_to_loadable_icon (p);

      if (this._avatar != null && new_avatar == null)
        {
          this._avatar = null;
          this.notify_property ("avatar");
        }
      else if ((this._avatar == null && new_avatar != null) ||
          (this._avatar != null && new_avatar != null &&
           ((!) this._avatar).equal (new_avatar) == false))
        {
          this._avatar = new_avatar;
          this.notify_property ("avatar");
        }
    }

  private void _update_urls (bool create_if_not_exist, bool emit_notification = true)
    {
      /* See the comments in Folks.Individual about the lazy instantiation
       * strategy for URIs. */
      if (this._urls == null && create_if_not_exist == false)
        {
          if (emit_notification)
            {
              this.notify_property ("urls");
            }
          return;
        }
      else if (this._urls == null)
        {
          this._urls = new SmallSet<UrlFieldDetails> (
              AbstractFieldDetails<string>.hash_static,
              AbstractFieldDetails<string>.equal_static);
          this._urls_ro = this._urls.read_only_view;
        }

      var new_urls = new SmallSet<UrlFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

      /* First we get the standard Evo urls.. */
      foreach (unowned UrlTypeMapping mapping in Persona._url_properties)
        {
          unowned var url_property = mapping.vcard_field_name;
          unowned var folks_type = mapping.folks_type;

          unowned var u = this._get_string_property (url_property);
          if (u != null && u != "")
            {
              var fd_u = new UrlFieldDetails ((!) u);
              fd_u.set_parameter (AbstractFieldDetails.PARAM_TYPE, folks_type);
              new_urls.add (fd_u);
            }
        }

      /* Now we go for extra URLs */
      unowned E.VCard vcard = (E.VCard) this.contact;
      foreach (unowned E.VCardAttribute attr in vcard.get_attributes ())
        {
          if (attr.get_name () == "X-URIS")
            {
              unowned var val = get_vcard_attr_value (attr);
              if (val == null || (!) val == "")
                {
                  continue;
                }

              var url_fd = new UrlFieldDetails ((!) val);
              this._update_params (url_fd, attr);
              new_urls.add (url_fd);
            }
        }

      if (!Utils.set_afd_equal (new_urls, this._urls))
        {
          this._urls = new_urls;
          this._urls_ro = new_urls.read_only_view;
          if (emit_notification)
            {
              this.notify_property ("urls");
            }
        }
    }

  private void _update_im_addresses ()
    {
      unowned var im_eds_map = Persona._get_im_eds_map ();
      var new_im_addresses = new HashMultiMap<string, ImFieldDetails> (null,
          null, AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

      foreach (unowned string im_proto in im_eds_map.get_keys ())
        {
          var addresses = this.contact.get_attributes (
              im_eds_map.lookup (im_proto));
          foreach (unowned E.VCardAttribute attr in addresses)
            {
              try
                {
                  unowned var addr = get_vcard_attr_value (attr);
                  if (addr == null || (!) addr == "")
                    {
                      continue;
                    }

                  string normalised_addr =
                    ImDetails.normalise_im_address ((!) addr, im_proto);

                  if (normalised_addr == "")
                    {
                      continue;
                    }

                  var im_fd = new ImFieldDetails (normalised_addr);
                  new_im_addresses.set (im_proto, im_fd);
                }
              catch (Folks.ImDetailsError e)
                {
                  GLib.warning (
                      "Problem when trying to normalise address: %s\n",
                      e.message);
                }
            }
        }

      /* We consider some e-mail addresses to be IM IDs too. This
       * is pretty much a hack to make sure EDS contacts are
       * automatically linked with their corresponding Telepathy
       * Persona. As an undesired side effect we might end up having
       * IM addresses that aren't actually used as such (i.e.: people
       * who don't actually use GMail or MSN addresses for IM): this can be
       * detected by clients by looking for the
       * {@link Edsf.Persona.folks_field_attribute_name} parameter existing and
       * being set to `TRUE` on the {@link ImFieldDetails}.
       *
       * See: bgo#657142, bgo#723187
       */
      foreach (var email in this._email_addresses)
        {
          unowned var _proto = this._im_proto_from_addr (email.value);
          if (_proto != null)
            {
              unowned var proto = (!) _proto;

              /* Has this already been added? */
              var exists = false;
              Collection<ImFieldDetails>? current_im_addrs =
                  new_im_addresses.get (proto);
              if (current_im_addrs != null)
                {
                  foreach (var cur_im in (!) current_im_addrs)
                    {
                      if (cur_im.value == email.value)
                        {
                          exists = true;
                          break;
                        }
                    }
                }

              if (exists)
                continue;

              try
                {
                  string normalised_addr =
                    ImDetails.normalise_im_address (email.value, proto);
                  var im_fd = new ImFieldDetails (normalised_addr);

                  im_fd.add_parameter (
                      Edsf.Persona.folks_field_attribute_name, "TRUE");
                  new_im_addresses.set (proto, im_fd);
                }
              catch (Folks.ImDetailsError e)
                {
                  GLib.warning (
                      "Problem when trying to normalise address: %s\n",
                      e.message);
                }
            }
        }

      if (!Utils.multi_map_str_afd_equal (new_im_addresses,
              this._im_addresses))
        {
          this._im_addresses = new_im_addresses;
          this.notify_property ("im-addresses");
        }
    }

  private void _update_groups (bool create_if_not_exist, bool emit_notification = true)
    {
      /* See the comments in Folks.Individual about the lazy instantiation
       * strategy for groups. */
      if (this._groups == null && create_if_not_exist == false)
        {
          if (emit_notification)
            {
              this.notify_property ("groups");
            }
          return;
        }

      var category_names =
          this._contact.get<GLib.List<string>> (E.ContactField.CATEGORY_LIST);
      var new_categories = new SmallSet<string> ();
      bool any_added_categories = false;

      foreach (unowned string category_name in category_names)
        {
          /* Skip the “Starred in Android” group for Google personas; we handle
           * it later. */
          if (((Edsf.PersonaStore) store)._is_google_contacts_address_book () &&
              category_name == Edsf.PersonaStore.android_favourite_group_name)
            {
              continue;
            }

          new_categories.add (category_name);

          /* Is this a new category? */
          if (this._groups == null || !this._groups.contains (category_name))
            {
              any_added_categories = true;
            }
        }

      /* Work out if categories have been removed. */
      bool any_removed_categories = false;

      if (this._groups != null)
        {
          foreach (var category_name in this._groups)
            {
              /* Skip the “Starred in Android” group for Google personas; we handle
               * it later. */
              if (((Edsf.PersonaStore) store)._is_google_contacts_address_book () &&
                  category_name == Edsf.PersonaStore.android_favourite_group_name)
                {
                  continue;
                }

              if (!new_categories.contains (category_name))
                {
                  any_removed_categories = true;
                }
            }
        }

      this._groups = new_categories;
      this._groups_ro = this._groups.read_only_view;

      /* Check our new set of system groups if this is a Google address book. */
      unowned var store = (Edsf.PersonaStore) this.store;
      var in_google_personal_group = false;
      var should_notify_sysgroups = false;

      if (store._is_google_contacts_address_book ())
        {
          unowned var vcard = (E.VCard) this.contact;
          unowned E.VCardAttribute? attr =
             vcard.get_attribute ("X-GOOGLE-SYSTEM-GROUP-IDS");
          if (attr != null)
            {
              unowned GLib.List<string> system_group_ids = attr.get_values();
              var new_sysgroups = new SmallSet<string> ();
              bool any_added_sysgroups = false;

              foreach (unowned string system_group_id in system_group_ids)
                {
                  new_sysgroups.add (system_group_id);

                  if (this._system_groups == null ||
                      !this._system_groups.contains (system_group_id))
                    {
                      any_added_sysgroups = true;
                    }
                }

              /* Work out if categories have been removed. */
              bool any_removed_sysgroups = false;

              if (this._system_groups != null)
                {
                  foreach (var system_group_id in this._system_groups)
                    {
                      if (!new_sysgroups.contains (system_group_id))
                        {
                          any_removed_sysgroups = true;
                        }
                    }
                }

              /* If we're in the GDATA_CONTACTS_GROUP_CONTACTS group, then
               * we're in the user's "My Contacts" address book, as opposed
               * to their "Other" address book. */
              if (new_sysgroups.contains (GOOGLE_PERSONAL_GROUP_NAME))
                {
                  in_google_personal_group = true;
                }

              this._system_groups = new_sysgroups;
              this._system_groups_ro = new_sysgroups.read_only_view;

              if (any_added_sysgroups || any_removed_sysgroups)
                should_notify_sysgroups = true;
            }
          else
            {
              this._system_groups = new SmallSet<string>();
              this._system_groups_ro = this._system_groups.read_only_view;
            }
        }

      /* Check whether our favourite status needs updating. */
      var old_is_favourite = this._is_favourite;

      if (store._is_google_contacts_address_book ())
        {
          this._is_favourite = false;

          foreach (unowned string category_name in category_names)
            {
              /* We link the “Starred in Android” group to Google Contacts
               * address books. See: bgo#661490. */
              if (category_name ==
                  Edsf.PersonaStore.android_favourite_group_name)
                {
                  this._is_favourite = true;
                }
            }
        }

      /* Notify if anything's changed. */
      this.freeze_notify ();

      if ((any_added_categories || any_removed_categories) &&
          emit_notification)
        {
          this.notify_property ("groups");
        }
      if (should_notify_sysgroups && emit_notification)
        {
          this.notify_property ("system-groups");
        }
      if (this._is_favourite != old_is_favourite && emit_notification)
        {
          this.notify_property ("is-favourite");
        }
      if (in_google_personal_group != this._in_google_personal_group)
        {
          this._in_google_personal_group = in_google_personal_group;
          if (emit_notification)
            {
              this.notify_property ("in-google-personal-group");
            }
        }

      this.thaw_notify ();
   }

  /**
   * build a table of im protocols / im protocol aliases
   */
  internal static unowned GLib.HashTable<unowned string, E.ContactField> _get_im_eds_map ()
    {
      if (Edsf.Persona._im_eds_map == null)
        {
          var table =
              new GLib.HashTable<unowned string, E.ContactField> (str_hash,
                  str_equal);

          table.insert ("aim", ContactField.IM_AIM);
          table.insert ("yahoo", ContactField.IM_YAHOO);
          table.insert ("groupwise", ContactField.IM_GROUPWISE);
          table.insert ("jabber", ContactField.IM_JABBER);
          table.insert ("msn", ContactField.IM_MSN);
          table.insert ("icq", ContactField.IM_ICQ);
          table.insert ("gadugadu", ContactField.IM_GADUGADU);
          table.insert ("skype", ContactField.IM_SKYPE);

          Edsf.Persona._im_eds_map = table;
        }

      return (!) Edsf.Persona._im_eds_map;
    }

  private void _update_phones (bool create_if_not_exist, bool emit_notification = true)
    {
      /* See the comments in Folks.Individual about the lazy instantiation
       * strategy for phone numbers. */
      if (this._phone_numbers == null && create_if_not_exist == false)
        {
          this.notify_property ("phone-numbers");
          return;
        }
      else if (this._phone_numbers == null)
        {
          this._phone_numbers = new SmallSet<PhoneFieldDetails> (
              AbstractFieldDetails<string>.hash_static,
              AbstractFieldDetails<string>.equal_static);
          this._phone_numbers_ro = this._phone_numbers.read_only_view;
        }

      var new_phone_numbers = new SmallSet<PhoneFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

      var attrs = this.contact.get_attributes (E.ContactField.TEL);
      foreach (unowned E.VCardAttribute attr in attrs)
        {
          unowned var val = get_vcard_attr_value (attr);
          if (val == null || (!) val == "")
            {
              continue;
            }

          var phone_fd = new PhoneFieldDetails ((!) val);
          this._update_params (phone_fd, attr);
          new_phone_numbers.add (phone_fd);
        }

      // Does not use phone comparison because this will try to match only
      // numbers and will remove the prefix, and that could cause a wrong result
      // since the the phone number is stored as string
      if (!Utils.set_string_afd_equal (this._phone_numbers, new_phone_numbers))
        {
          this._phone_numbers = new_phone_numbers;
          this._phone_numbers_ro = new_phone_numbers.read_only_view;
          if (emit_notification)
            {
              this.notify_property ("phone-numbers");
            }
        }
   }

  private PostalAddress _postal_address_from_attribute (E.VCardAttribute attr)
    {
      unowned GLib.List<string>? values = attr.get_values();
      unowned GLib.List<string>? l = values;

      unowned var address_format = "";
      unowned var po_box = "";
      unowned var extension = "";
      unowned var street = "";
      unowned var locality = "";
      unowned var region = "";
      unowned var postal_code = "";
      unowned var country = "";

      if (l != null)
        {
          po_box = ((!) l).data;
          l = ((!) l).next;
        }
      if (l != null)
        {
          extension = ((!) l).data;
          l = ((!) l).next;
        }
      if (l != null)
        {
          street = ((!) l).data;
          l = ((!) l).next;
        }
      if (l != null)
        {
          locality = ((!) l).data;
          l = ((!) l).next;
        }
      if (l != null)
        {
          region = ((!) l).data;
          l = ((!) l).next;
        }
      if (l != null)
        {
          postal_code = ((!) l).data;
          l = ((!) l).next;
        }
      if (l != null)
        {
          country = ((!) l).data;
          l = ((!) l).next;
        }

      return new PostalAddress (po_box, extension, street,
                                locality, region, postal_code, country,
                                address_format, null);
    }

  /*
   * TODO: we should check if addresses corresponding to different types
   *       are the same and if so instantiate only one PostalAddress
   *       (with the given types).
   */
  private void _update_addresses (bool create_if_not_exist, bool emit_notification = true)
    {
      /* See the comments in Folks.Individual about the lazy instantiation
       * strategy for addresses. */
      if (this._postal_addresses == null && create_if_not_exist == false)
        {
          if (emit_notification)
            {
              this.notify_property ("postal-addresses");
            }
          return;
        }
      else if (this._postal_addresses == null)
        {
          this._postal_addresses = new SmallSet<PostalAddressFieldDetails> (
              AbstractFieldDetails<PostalAddress>.hash_static,
              AbstractFieldDetails<PostalAddress>.equal_static);
          this._postal_addresses_ro = this._postal_addresses.read_only_view;
        }

      var new_postal_addresses = new SmallSet<PostalAddressFieldDetails> (
          AbstractFieldDetails<PostalAddress>.hash_static,
          AbstractFieldDetails<PostalAddress>.equal_static);

      var attrs = this.contact.get_attributes (E.ContactField.ADDRESS);
      foreach (unowned E.VCardAttribute attr in attrs)
        {
          var address = this._postal_address_from_attribute (attr);
          if (address.is_empty ())
            {
              continue;
            }

          var pa_fd = new PostalAddressFieldDetails (address);
          this._update_params (pa_fd, attr);
          new_postal_addresses.add (pa_fd);
        }

      if (!Folks.Internal.equal_sets<PostalAddressFieldDetails> (
              new_postal_addresses,
              this._postal_addresses))
        {
          this._postal_addresses = new_postal_addresses;
          this._postal_addresses_ro = new_postal_addresses.read_only_view;
          if (emit_notification)
            {
              this.notify_property ("postal-addresses");
            }
        }
    }

  private void _update_local_ids ()
    {
      var new_local_ids = new SmallSet<string> ();

      unowned E.VCardAttribute ids =
          this.contact.get_attribute ("X-FOLKS-CONTACTS-IDS");
      if (ids != null)
        {
          unowned GLib.List<string> ids_v = ((!) ids).get_values ();

          foreach (unowned string local_id in ids_v)
            {
              if (local_id != "")
                {
                  new_local_ids.add (local_id);
                }
            }
        }

      /* Make sure it includes our local id */
      new_local_ids.add (this.iid);

      if (!Folks.Internal.equal_sets<string> (new_local_ids, this.local_ids))
        {
          this._local_ids = new_local_ids;
          this._local_ids_ro = this._local_ids.read_only_view;
          this.notify_property ("local-ids");
        }
    }

  private void _update_location ()
    {
      var _geo = this._get_property<E.ContactGeo> ("geo");

      if (_geo != null)
        {
          if (this._location == null ||
              // Report all changes to the location because someone must
              // have changed the values intentionally.
              !this._location.equal_coordinates (_geo.latitude, _geo.longitude))
            {
              if (this._location != null)
                {
                  // Update existing instance instead of destroying it
                  // and creating a new one. Minimizes memory thrashing.
                  this._location.latitude = _geo.latitude;
                  this._location.longitude = _geo.longitude;
                }
              else
                {
                  this._location = new Location (_geo.latitude, _geo.longitude);
                }
              this.notify_property ("location");
            }
        }
      else
        {
          if (this._location != null)
            {
              this._location = null;
              this.notify_property ("location");
            }
        }
    }

  private void _update_favourite ()
    {
      bool is_fav = false;

      unowned E.VCardAttribute fav =
          this.contact.get_attribute ("X-FOLKS-FAVOURITE");
      if (fav != null)
        {
          unowned var val = get_vcard_attr_value ((!) fav);
          if (val != null && ((!) val).down () == "true")
            {
              is_fav = true;
            }
        }

      if (is_fav != this._is_favourite)
        {
          this._is_favourite = is_fav;
          this.notify_property ("is-favourite");
        }
    }

  private void _update_anti_links ()
    {
      var new_anti_links = new SmallSet<string> ();

      unowned var vcard = (E.VCard) this.contact;
      foreach (unowned E.VCardAttribute attr in vcard.get_attributes ())
        {
          if (attr.get_name () != Edsf.PersonaStore.anti_links_attribute_name)
            {
              continue;
            }

          unowned var val = get_vcard_attr_value (attr);
          if (val == null || (!) val == "")
             {
              continue;
            }

          new_anti_links.add ((!) val);
        }

      if (!Folks.Internal.equal_sets<string> (new_anti_links, this._anti_links))
        {
          this._anti_links = new_anti_links;
          this._anti_links_ro = new_anti_links.read_only_view;
          this.notify_property ("anti-links");
        }
    }

  internal static T? _get_property_from_contact<T> (E.Contact contact,
      string prop_name)
    {
      T? prop_value = null;
      prop_value = contact.get<T> (E.Contact.field_id (prop_name));
      return prop_value;
    }

  private T? _get_property<T> (string prop_name)
    {
      return Edsf.Persona._get_property_from_contact<T> (this.contact,
          prop_name);
    }

  // Some helpers to prevent a lot of string copies
  private unowned string? _get_string_property (string prop_name)
    {
      var field = E.Contact.field_id (prop_name);
      return_val_if_fail (E.Contact.field_is_string (field), null);
      return contact.get_const<string> (field);
    }

  private unowned string? get_vcard_attr_value (E.VCardAttribute attr)
    {
      unowned var values = attr.get_values ();
      return (values != null)? values.data : null;
    }

  private unowned string? _im_proto_from_addr (string addr)
    {
      if (addr.index_of ("@") == -1)
        return null;

      var tokens = addr.split ("@", 2);

      if (tokens.length != 2)
        return null;

      unowned var domain = tokens[1];
      if (domain.index_of (".") == -1)
        return null;

      tokens = domain.split (".", 2);

      if (tokens.length != 2)
        return null;

      domain = tokens[0];

      if (domain == "msn" ||
          domain == "hotmail" ||
          domain == "live")
        return "msn";
      else if (domain == "gmail" ||
          domain == "googlemail")
        return "jabber";
      else if (domain == "yahoo")
        return "yahoo";

      return null;
    }
}
