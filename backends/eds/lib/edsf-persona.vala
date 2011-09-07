/*
 * Copyright (C) 2011 Collabora Ltd.
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
 */
public class Edsf.Persona : Folks.Persona,
    AvatarDetails,
    BirthdayDetails,
    EmailDetails,
    GenderDetails,
    GroupDetails,
    ImDetails,
    LocalIdDetails,
    NameDetails,
    NoteDetails,
    PhoneDetails,
    RoleDetails,
    UrlDetails,
    PostalAddressDetails,
    WebServiceDetails
{
  /* The following 4 definitions are used by the tests */
  public static const string[] phone_fields = {
    "assistant_phone", "business_phone", "business_phone_2", "callback_phone",
    "car_phone", "company_phone", "home_phone", "home_phone_2", "isdn_phone",
    "mobile_phone", "other_phone", "primary_phone"
  };
  public static const string[] address_fields = {
    "address_home", "address_other", "address_work"
  };
  public static const string[] email_fields = {
    "email_1", "email_2", "email_3", "email_4"
  };
  public static const string[] url_properties = {
    "blog_url", "fburl", "homepage_url", "video_url"
  };

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
  public static const string gender_attribute_name = "X-GENDER";

  /**
   * The value used to define the male gender for the
   * X-GENDER vCard property.
   *
   * Based on:
   * [[http://tools.ietf.org/html/draft-ietf-vcarddav-vcardrev-22]]
   *
   * @since 0.6.0
   */
  public static const string gender_male = "M";

  /**
   * The value used to define the female gender for the
   * X-GENDER vCard property.
   *
   * Based on:
   * [[http://tools.ietf.org/html/draft-ietf-vcarddav-vcardrev-22]]
   *
   * @since 0.6.0
   */
  public static const string gender_female = "F";

  private const string[] _linkable_properties = { "im-addresses",
                                                  "local-ids",
                                                  "web-service-addresses" };

  private HashSet<PhoneFieldDetails> _phone_numbers;
  private Set<PhoneFieldDetails> _phone_numbers_ro;
  private HashSet<EmailFieldDetails> _email_addresses;
  private Set<EmailFieldDetails> _email_addresses_ro;
  private HashSet<NoteFieldDetails> _notes;
  private Set<NoteFieldDetails> _notes_ro;
  private static HashTable<string, E.ContactField> _im_eds_map = null;

  private HashSet<PostalAddressFieldDetails> _postal_addresses;
  private Set<PostalAddressFieldDetails> _postal_addresses_ro;

  private HashSet<string> _local_ids;
  private Set<string> _local_ids_ro;

  private HashMultiMap<string, WebServiceFieldDetails> _web_service_addresses;

  /**
   * The e-d-s contact represented by this Persona
   */
  public E.Contact contact
    {
      get;
      private set;
    }

  /**
   * {@inheritDoc}
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
   * @since UNRELEASED
   */
  public async void change_web_service_addresses (
      MultiMap<string, WebServiceFieldDetails> web_service_addresses)
          throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_web_service_addresses (this,
          web_service_addresses);
    }

  /**
   * IDs used to link {@link Edsf.Persona}s.
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
   * @since UNRELEASED
   */
  public async void change_local_ids (Set<string> local_ids)
      throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_local_ids (this, local_ids);
    }

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
      get { return this._postal_addresses_ro; }
      set { this.change_postal_addresses.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public async void change_postal_addresses (
      Set<PostalAddressFieldDetails> postal_addresses) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_postal_addresses (this,
          postal_addresses);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
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
   * @since UNRELEASED
   */
  public async void change_phone_numbers (
      Set<PhoneFieldDetails> phone_numbers) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_phones (this, phone_numbers);
    }

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
   * @since UNRELEASED
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
   * @since 0.6.0
   */
  [CCode (notify = false)]
  public Set<NoteFieldDetails> notes
    {
      get { return this._notes_ro; }
      set { this.change_notes.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
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
      get { return this._linkable_properties; }
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
   * @since UNRELEASED
   */
  public async void change_avatar (LoadableIcon? avatar) throws PropertyError
    {
      if (this._avatar == null ||
          !this._avatar.equal (avatar))
        {
          yield ((Edsf.PersonaStore) this.store)._set_avatar (this, avatar);
        }
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
   * @since UNRELEASED
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
   * @since 0.6.0
   */
  public string contact_id { get; private set; }

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
   * @since UNRELEASED
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
   * @since UNRELEASED
   */
  public async void change_nickname (string nickname) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_nickname (this, nickname);
    }

  private Gender _gender;
  /**
   * {@inheritDoc}
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
   * @since UNRELEASED
   */
  public async void change_gender (Gender gender) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_gender (this, gender);
    }

  private HashSet<UrlFieldDetails> _urls;
  private Set<UrlFieldDetails> _urls_ro;
  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
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
   * @since UNRELEASED
   */
  public async void change_urls (Set<UrlFieldDetails> urls) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_urls (this, urls);
    }

  private HashMultiMap<string, ImFieldDetails> _im_addresses =
      new HashMultiMap<string, ImFieldDetails> (null, null,
          (GLib.HashFunc) ImFieldDetails.hash,
          (GLib.EqualFunc) ImFieldDetails.equal);

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
   * @since UNRELEASED
   */
  public async void change_im_addresses (
      MultiMap<string, ImFieldDetails> im_addresses) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_im_fds (this, im_addresses);
    }

  private HashSet<string> _groups;
  private Set<string> _groups_ro;

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  [CCode (notify = false)]
  public Set<string> groups
    {
      get { return this._groups_ro; }
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
      /* Nothing to do? */
      if ((is_member == true && this._groups.contains (group) == true) ||
          (is_member == false && this._groups.contains (group) == false))
        {
          return;
        }

      /* Replace the current set of groups with a modified one. */
      var new_groups = new HashSet<string> ();
      foreach (var category_name in this._groups)
        {
          new_groups.add (category_name);
        }

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
   * @since UNRELEASED
   */
  public async void change_groups (Set<string> groups) throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_groups (this, groups);
    }

  /**
   * {@inheritDoc}
   *
   * e-d-s has no equivalent field, so this is unsupported.
   *
   * @since UNRELEASED
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
   * @since UNRELEASED
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
   * @since UNRELEASED
   */
  public async void change_birthday (DateTime? bday)
      throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_birthday (this,
          bday);
    }

  private HashSet<RoleFieldDetails> _roles;
  private Set<RoleFieldDetails> _roles_ro;

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  [CCode (notify = false)]
  public Set<RoleFieldDetails> roles
    {
      get { return this._roles_ro; }
      set { this.change_roles.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public async void change_roles (Set<RoleFieldDetails> roles)
      throws PropertyError
    {
      yield ((Edsf.PersonaStore) this.store)._set_roles (this, roles);
    }

  /**
   * Build a IID.
   *
   * @param store_id the {@link PersonaStore.id}
   * @param contact the Contact
   * @return a valid IID
   *
   * @since 0.6.0
   */
  internal static string build_iid_from_contact (string store_id,
      E.Contact contact)
    {
      var contact_id =
          (string) Edsf.Persona._get_property_from_contact (contact, "id");
      return Edsf.Persona.build_iid (store_id, contact_id);
    }

  /**
   * Build a IID.
   *
   * @param store_id the {@link PersonaStore.id}
   * @param contact_id the id belonging to the Contact
   * @return a valid IID
   *
   * @since 0.6.0
   */
  internal static string build_iid (string store_id, string contact_id)
    {
      return "%s:%s".printf (store_id, contact_id);
    }


  /**
   * Create a new persona.
   *
   * Create a new persona for the {@link PersonaStore} `store`, representing
   * the EDS contact given by `contact`.
   *
   * @since 0.6.0
   */
  public Persona (PersonaStore store, E.Contact contact)
    {
      var contact_id =
        (string) Edsf.Persona._get_property_from_contact (contact, "id");
      var uid = this.build_uid (BACKEND_NAME, store.id, contact_id);
      var iid = Edsf.Persona.build_iid (store.id, contact_id);
      var is_user = BookClient.is_self (contact);
      var full_name =
          (string) Edsf.Persona._get_property_from_contact (contact,
              "full_name");

      debug ("Creating new Edsf.Persona with IID '%s'", iid);

      Object (display_id: full_name,
              uid: uid,
              iid: iid,
              store: store,
              is_user: is_user);

      this._gender = Gender.UNSPECIFIED;
      this.contact_id = contact_id;
      this._phone_numbers = new HashSet<PhoneFieldDetails> (
          (GLib.HashFunc) PhoneFieldDetails.hash,
          (GLib.EqualFunc) PhoneFieldDetails.equal);
      this._phone_numbers_ro = this._phone_numbers.read_only_view;
      this._email_addresses = new HashSet<EmailFieldDetails> (
          (GLib.HashFunc) EmailFieldDetails.hash,
          (GLib.EqualFunc) EmailFieldDetails.equal);
      this._email_addresses_ro = this._email_addresses.read_only_view;
      this._notes = new HashSet<NoteFieldDetails> (
          (GLib.HashFunc) NoteFieldDetails.hash,
          (GLib.EqualFunc) NoteFieldDetails.equal);
      this._notes_ro = this._notes.read_only_view;
      this._urls = new HashSet<UrlFieldDetails> (
          (GLib.HashFunc) UrlFieldDetails.hash,
          (GLib.EqualFunc) UrlFieldDetails.equal);
      this._urls_ro = this._urls.read_only_view;
      this._postal_addresses = new HashSet<PostalAddressFieldDetails> (
          (GLib.HashFunc) PostalAddressFieldDetails.hash,
          (GLib.EqualFunc) PostalAddressFieldDetails.equal);
      this._postal_addresses_ro = this._postal_addresses.read_only_view;
      this._local_ids = new HashSet<string> ();
      this._local_ids_ro = this._local_ids.read_only_view;
      this._web_service_addresses =
        new HashMultiMap<string, WebServiceFieldDetails> (
            null, null,
            (GLib.HashFunc) WebServiceFieldDetails.hash,
            (GLib.EqualFunc) WebServiceFieldDetails.equal);
      this._groups = new HashSet<string> ();
      this._groups_ro = this._groups.read_only_view;
      this._roles = new HashSet<RoleFieldDetails> (
          (GLib.HashFunc) RoleFieldDetails.hash,
          (GLib.EqualFunc) RoleFieldDetails.equal);
      this._roles_ro = this._roles.read_only_view;

      this._update (contact);
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
          foreach (var protocol in this._im_addresses.get_keys ())
            {
              var im_fds = this._im_addresses.get (protocol);

              foreach (var im_fd in im_fds)
                  callback (protocol + ":" + im_fd.value);
            }
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
          foreach (var web_service in this.web_service_addresses.get_keys ())
            {
              var web_service_addresses =
                  this._web_service_addresses.get (web_service);

              foreach (var ws_fd in web_service_addresses)
                  callback (web_service + ":" + ws_fd.value);
            }
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
  internal void _update (E.Contact contact)
    {
      this.contact = contact;

      this._update_names ();
      this._update_avatar ();
      this._update_urls ();
      this._update_phones ();
      this._update_addresses ();
      this._update_emails ();
      this._update_im_addresses ();
      this._update_groups ();
      this._update_notes ();
      this._update_local_ids ();
      this._update_web_services_addresses ();
      this._update_gender ();
      this._update_birthday ();
      this._update_roles ();
    }

  private void _update_params (AbstractFieldDetails details,
      E.VCardAttribute attr)
    {
      foreach (unowned E.VCardAttributeParam param in attr.get_params ())
        {
          string param_name = param.get_name ().down ();
          foreach (unowned string param_value in param.get_values ())
            {
              details.add_parameter (param_name, param_value);
            }
        }
    }

  private void _update_gender ()
    {
      var gender = Gender.UNSPECIFIED;
      var gender_attr =
          this.contact.get_attribute (Edsf.Persona.gender_attribute_name);

      if (gender_attr != null)
        {
          var gender_str = gender_attr.get_value ().up ();

          if (gender_str == Edsf.Persona.gender_male)
            {
              gender = Gender.MALE;
            }
          else if (gender_str == Edsf.Persona.gender_female)
            {
              gender = Gender.FEMALE;
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
      E.ContactDate? bday = (E.ContactDate?) this._get_property ("birth_date");

      if (bday != null)
        {
          /* Since e-d-s stores birthdays as a plain date, we take the
           * given date in local time and convert it to UTC as mandated
           * by the BirthdayDetails interface */
          var d = new DateTime.local ((int) bday.year, (int) bday.month,
              (int) bday.day, 0, 0, 0.0);
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
          if (this._birthday != null)
            {
              this._birthday = null;
              this.notify_property ("birthday");
            }
        }
    }

  private void _update_roles ()
    {
      var new_roles = new HashSet<RoleFieldDetails> (
          (GLib.HashFunc) RoleFieldDetails.hash,
          (GLib.EqualFunc) RoleFieldDetails.equal);

      var default_role_fd = this._get_default_role ();
      if (default_role_fd != null)
        {
          new_roles.add (default_role_fd);
        }

      var vcard = (E.VCard) this.contact;
      foreach (unowned E.VCardAttribute attr in vcard.get_attributes ())
        {
          if (attr.get_name () != "X-ROLES")
            continue;

          var role = new Role ("", "");
          role.role = attr.get_value ();
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

      var comp = new Edsf.SetComparator<RoleFieldDetails> ();
      if (new_roles.size > 0 &&
          !comp.equal (new_roles, this._roles))
        {
          this._roles = new_roles;
          this._roles_ro = new_roles.read_only_view;
          this.notify_property ("roles");
        }
      else if (new_roles.size == 0)
        {
          this._roles.clear ();
          this.notify_property ("roles");
        }
    }

  private RoleFieldDetails? _get_default_role ()
    {
      RoleFieldDetails? default_role = null;

      var org = (string?) this._get_property ("org");
      var org_unit = (string?) this._get_property ("org_unit");
      var office = (string?) this._get_property ("office");
      var title = (string?) this._get_property ("title");
      var role = (string?) this._get_property ("role");
      var manager = (string?) this._get_property ("manager");
      var assistant = (string?) this._get_property ("assistant");

      if (org != null ||
          org_unit != null ||
          office != null ||
          title != null ||
          role != null ||
          manager != null ||
          assistant != null)
        {
          var new_role = new Role (title, org);
          if (role != null)
            new_role.role = role;

          default_role = new RoleFieldDetails (new_role);

          if (org_unit != null)
            default_role.set_parameter ("org_unit", org_unit);

          if (office != null)
            default_role.set_parameter ("office", office);

          if (manager != null)
            default_role.set_parameter ("manager", manager);

          if (assistant != null)
            default_role.set_parameter ("assistant", assistant);
        }

      return default_role;
    }

  private void _update_web_services_addresses ()
    {
      /* FIXME: we shouldn't immediately replace the current set of web
       * services. Instead we should construct a new set, compare and then
       * replace if they are actually different. Same applies for all other
       * properties. */
      this._web_service_addresses.clear ();

      var services = this.contact.get_attribute ("X-FOLKS-WEB-SERVICES-IDS");
      if (services != null)
        {
          foreach (var service in services.get_params ())
            {
              var service_name = service.get_name ().down ();
              foreach (var service_id in service.get_values ())
                {
                  if (service_id == null)
                    continue;

                  this._web_service_addresses.set (service_name,
                      new WebServiceFieldDetails (service_id));
                }
            }
        }

      this.notify_property ("web-service-addresses");
    }

  private void _update_emails ()
    {
      this._email_addresses.clear ();

      var attrs = this.contact.get_attributes (E.ContactField.EMAIL);
      foreach (var attr in attrs)
        {
          var email_fd = new EmailFieldDetails (attr.get_value ());
          this._update_params (email_fd, attr);
          this._email_addresses.add (email_fd);
        }

      this.notify_property ("email-addresses");
    }

  private void _update_notes ()
    {
      this._notes.clear ();

      string n = (string) this._get_property ("note");
      if (n != null && n != "")
        {
          var note = new NoteFieldDetails (n);
          this._notes.add (note);
        }

      this.notify_property ("notes");
    }

  private void _update_names ()
    {
      string full_name = (string) this._get_property ("full_name");

      if (full_name == null)
        {
          full_name = "";
        }

      if (this._full_name != full_name)
        {
          this._full_name = full_name;
          this.notify_property ("full-name");
        }

      string nickname = (string) this._get_property ("nickname");

      if (nickname == null)
        {
          nickname = "";
        }

      if (this._nickname != nickname)
        {
          this._nickname = nickname;
          this.notify_property ("nickname");
        }

      StructuredName? structured_name = null;
      E.ContactName? cn = (E.ContactName) this._get_property ("name");
      if (cn != null)
        {
          string family_name = cn.family;
          string given_name  = cn.given;
          string additional_names = cn.additional;
          string prefixes = cn.prefixes;
          string suffixes = cn.suffixes;
          structured_name = new StructuredName (family_name, given_name,
                                                additional_names, prefixes,
                                                suffixes);
        }

      if (structured_name != null && !structured_name.is_empty ())
        {
          this._structured_name = structured_name;
          this.notify_property ("structured-name");
        }
      else if (this._structured_name != null)
        {
          this._structured_name = null;
          this.notify_property ("structured-name");
        }
    }

  private LoadableIcon? _contact_photo_to_loadable_icon (ContactPhoto? p)
    {
      if (p == null)
        {
          return null;
        }

      switch (p.type)
        {
          case ContactPhotoType.URI:
            if (p.get_uri () == null)
              {
                return null;
              }

            return new FileIcon (File.new_for_uri (p.get_uri ()));
          case ContactPhotoType.INLINED:
            if (p.get_mime_type () == null || p.get_inlined () == null)
              {
                return null;
              }

            return new Edsf.MemoryIcon (p.get_mime_type (), p.get_inlined ());
          default:
            return null;
        }
    }

  private void _update_avatar ()
    {
      E.ContactPhoto? p = (E.ContactPhoto) this._get_property ("photo");

      var cache = AvatarCache.dup ();

      // Convert the ContactPhoto to a LoadableIcon and store or update it.
      var new_avatar = this._contact_photo_to_loadable_icon (p);

      if (this._avatar != null && new_avatar == null)
        {
          // Remove the old cached avatar, ignoring errors.
          cache.remove_avatar.begin (this.uid, (obj, res) =>
            {
              try
                {
                  cache.remove_avatar.end (res);
                }
              catch (GLib.Error e1) {}

              this._avatar = null;
              this.notify_property ("avatar");
            });
        }
      else if ((this.avatar == null && new_avatar != null) ||
          (this.avatar != null && new_avatar != null &&
           this._avatar.equal (new_avatar) == false))
        {
          // Store the new avatar in the cache.
          cache.store_avatar.begin (this.uid, new_avatar, (obj, res) =>
            {
              try
                {
                  cache.store_avatar.end (res);
                  this._avatar = new_avatar;
                  this.notify_property ("avatar");
                }
              catch (GLib.Error e2)
                {
                  warning ("Couldn't cache avatar for Edsf.Persona '%s': %s",
                      this.uid, e2.message);
                  new_avatar = null; /* failure */
                }
            });
        }
    }

  private void _update_urls ()
    {
      this._urls.clear ();
      var urls_temp = new HashSet<UrlFieldDetails> ();

      /* First we get the standard Evo urls.. */
      foreach (string url_property in this.url_properties)
        {
          string u = (string) this._get_property (url_property);
          if (u != null && u != "")
            {
              var fd_u = new UrlFieldDetails (u);
              fd_u.set_parameter("type", url_property);
              urls_temp.add (fd_u);
            }
        }

      /* Now we go for extra URLs */
      var vcard = (E.VCard) this.contact;
      foreach (unowned E.VCardAttribute attr in vcard.get_attributes ())
        {
          if (attr.get_name () == "X-URIS")
            {
              var url_fd = new UrlFieldDetails (attr.get_value ());
              this._update_params (url_fd, attr);
              urls_temp.add (url_fd);
            }
        }

      if (!Utils.set_afd_equal (urls_temp, this._urls))
        {
          this._urls.clear ();

          foreach (var url_fd in urls_temp)
            {
              this._urls.add (url_fd);
            }

         this.notify_property ("urls");
        }
    }

  private void _update_im_addresses ()
    {
      var im_eds_map = this._get_im_eds_map ();
      this._im_addresses.clear ();

      foreach (var im_proto in im_eds_map.get_keys ())
        {
          var addresses = this.contact.get_attributes (
              im_eds_map.lookup (im_proto));
          foreach (var attr in addresses)
            {
              try
                {
                  var addr = attr.get_value ();
                  string normalised_addr =
                    (owned) ImDetails.normalise_im_address (addr, im_proto);
                  var im_fd = new ImFieldDetails (normalised_addr);
                  this._im_addresses.set (im_proto, im_fd);
                }
              catch (Folks.ImDetailsError e)
                {
                  GLib.warning (
                      "Problem when trying to normalise address: %s\n",
                      e.message);
                }
            }
        }

      this.notify_property ("im-addresses");
    }

  private void _update_groups ()
    {
      unowned GLib.List<string> category_names =
          (GLib.List<string>) this._contact.get (E.ContactField.CATEGORY_LIST);
      var new_categories = new HashSet<string> ();
      var added_categories = new LinkedList<string> ();

      foreach (var category_name in category_names)
        {
          new_categories.add (category_name);

          /* Is this a new category? */
          if (!this._groups.contains (category_name))
            {
              added_categories.add (category_name);
            }
        }

      /* Work out which categories have been removed. */
      var removed_categories = new LinkedList<string> ();

      foreach (var category_name in this._groups)
        {
          if (!new_categories.contains (category_name))
            {
              removed_categories.add (category_name);
            }
        }

      /* Make the changes to this._groups and emit signals. */
      foreach (var category_name in removed_categories)
        {
          this.group_changed (category_name, false);
          this._groups.remove (category_name);
        }

      foreach (var category_name in added_categories)
        {
          this._groups.add (category_name);
          this.group_changed (category_name, true);
        }

      /* Notify if anything's changed. */
      if (added_categories.size != 0 || removed_categories.size != 0)
        {
          this.notify_property ("groups");
        }
   }

  /**
   * build a table of im protocols / im protocol aliases
   */
  internal static HashTable<string, E.ContactField> _get_im_eds_map ()
    {
      lock (Edsf.Persona._im_eds_map)
        {
          if (Edsf.Persona._im_eds_map == null)
            {
              Edsf.Persona._im_eds_map =
                new HashTable<string, E.ContactField> (str_hash, str_equal);
              Edsf.Persona._im_eds_map.insert ("aim", ContactField.IM_AIM);
              Edsf.Persona._im_eds_map.insert ("yahoo", ContactField.IM_YAHOO);
              Edsf.Persona._im_eds_map.insert ("groupwise",
                  ContactField.IM_GROUPWISE);
              Edsf.Persona._im_eds_map.insert ("jabber",
                  ContactField.IM_JABBER);
              Edsf.Persona._im_eds_map.insert ("msn",
                  ContactField.IM_MSN);
              Edsf.Persona._im_eds_map.insert ("icq",
                  ContactField.IM_ICQ);
              Edsf.Persona._im_eds_map.insert ("gadugadu",
                  ContactField.IM_GADUGADU);
              Edsf.Persona._im_eds_map.insert ("skype",
                  ContactField.IM_SKYPE);
            }
        }

      return Edsf.Persona._im_eds_map;
    }

  private void _update_phones ()
    {
      this._phone_numbers.clear ();

      var attrs = this.contact.get_attributes (E.ContactField.TEL);
      foreach (var attr in attrs)
        {
          var phone_fd = new PhoneFieldDetails (attr.get_value ());
          this._update_params (phone_fd, attr);
          this._phone_numbers.add (phone_fd);
        }

     this.notify_property ("phone-numbers");
   }

  private PostalAddress _postal_address_from_attribute (E.VCardAttribute attr)
    {
      unowned GLib.List<string?> values = attr.get_values();
      unowned GLib.List<string?> l = values;

      var address_format = "";
      var po_box = "";
      var extension = "";
      var street = "";
      var locality = "";
      var region = "";
      var postal_code = "";
      var country = "";

      if (l != null)
        {
          po_box = l.data;
          l = l.next;
        }
      if (l != null)
        {
          extension = l.data;
          l = l.next;
        }
      if (l != null)
        {
          street = l.data;
          l = l.next;
        }
      if (l != null)
        {
          locality = l.data;
          l = l.next;
        }
      if (l != null)
        {
          region = l.data;
          l = l.next;
        }
      if (l != null)
        {
          postal_code = l.data;
          l = l.next;
        }
      if (l != null)
        {
          country = l.data;
          l = l.next;
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
  private void _update_addresses ()
    {
      this._postal_addresses.clear ();

      var attrs = this.contact.get_attributes (E.ContactField.ADDRESS);
      foreach (unowned E.VCardAttribute attr in attrs)
        {
          var pa_fd = new PostalAddressFieldDetails (
              this._postal_address_from_attribute (attr));
          this._update_params (pa_fd, attr);
          this._postal_addresses.add (pa_fd);
        }

      this.notify_property ("postal-addresses");
    }

  private void _update_local_ids ()
    {
      this._local_ids.clear ();

      var ids = this.contact.get_attribute ("X-FOLKS-CONTACTS-IDS");
      if (ids != null)
        {
          unowned GLib.List<string> ids_v = ids.get_values ();

          foreach (var local_id in ids_v)
            {
              this._local_ids.add (local_id);
            }
        }

      this.notify_property ("local-ids");
    }

  internal static void * _get_property_from_contact (E.Contact contact,
      string prop_name)
    {
      void *prop_value = null;
      prop_value = contact.get (E.Contact.field_id (prop_name));
      return prop_value;
    }

  private void * _get_property (string prop_name)
    {
      return Edsf.Persona._get_property_from_contact (this.contact,
          prop_name);
    }
}
