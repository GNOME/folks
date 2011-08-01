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
    EmailDetails,
    GenderDetails,
    GroupDetails,
    ImDetails,
    LocalIdDetails,
    NameDetails,
    NoteDetails,
    PhoneDetails,
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
  private const string[] _linkable_properties = { "im-addresses",
                                                  "local-ids",
                                                  "web-service-addresses" };
  private const string[] _writeable_properties =
    {
      "web-service-addresses",
      "local-ids",
      "postal-addresses",
      "phone-numbers",
      "email-addresses",
      "notes",
      "avatar",
      "structured-name",
      "full-name",
      "nickname",
      "im-addresses",
      "groups"
    };
  private HashSet<FieldDetails> _phone_numbers;
  private Set<FieldDetails> _phone_numbers_ro;
  private HashSet<FieldDetails> _email_addresses;
  private Set<FieldDetails> _email_addresses_ro;
  private HashSet<Note> _notes;
  private Set<Note> _notes_ro;
  private static HashTable<string, E.ContactField> _im_eds_map = null;

  private HashSet<PostalAddress> _postal_addresses;
  private Set<PostalAddress> _postal_addresses_ro;

  private HashSet<string> _local_ids;
  private Set<string> _local_ids_ro;

  private HashMultiMap<string, string> _web_service_addresses;

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
  public MultiMap<string, string> web_service_addresses
    {
      get { return this._web_service_addresses; }
      set
        {
          var store = (Edsf.PersonaStore) this.store;
          store._set_web_service_addresses (this, value);
        }
    }

  /**
   * IDs used to link {@link Edsf.Persona}s.
   */
  public Set<string> local_ids
    {
      get
        {
          if (this._local_ids.contains (this.contact_id) == false)
            {
              this._local_ids.add (this.contact_id);
            }
          return this._local_ids_ro;
        }
      set
        {
          ((Edsf.PersonaStore) this.store)._set_local_ids (this, value);
        }
    }

  /**
   * The postal addresses of the contact.
   *
   * A list of postal addresses associated to the contact.
   *
   * @since 0.5.UNRELEASED
   */
  public Set<PostalAddress> postal_addresses
    {
      get { return this._postal_addresses_ro; }
      private set
        {
          ((Edsf.PersonaStore) this.store)._set_postal_addresses (this, value);
        }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.5.UNRELEASED
   */
  public Set<FieldDetails> phone_numbers
    {
      get { return this._phone_numbers_ro; }
      private set
        {
          ((Edsf.PersonaStore) this.store)._set_phones (this, value);
        }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.5.UNRELEASED
   */
  public Set<FieldDetails> email_addresses
    {
      get { return this._email_addresses_ro; }
      private set
        {
          ((Edsf.PersonaStore) this.store)._set_emails (this, value);
        }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.5.UNRELEASED
   */
  public Set<Note> notes
    {
      get { return this._notes_ro; }
      private set
        {
          ((Edsf.PersonaStore) this.store)._set_notes (this, value);
        }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.5.UNRELEASED
   */
  public override string[] linkable_properties
    {
      get { return this._linkable_properties; }
    }

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public override string[] writeable_properties
    {
      get { return this._writeable_properties; }
    }

  private LoadableIcon? _avatar = null;
  /**
   * An avatar for the Persona.
   *
   * See {@link Folks.Avatar.avatar}.
   *
   * @since 0.5.UNRELEASED
   */
  public LoadableIcon? avatar
    {
      get { return this._avatar; }
      set
        {
          if (this._avatar == null ||
              !this._avatar.equal (value))
            {
              ((Edsf.PersonaStore) this.store)._set_avatar (this, value);
            }
        }
    }

  private StructuredName _structured_name;
  /**
   * {@inheritDoc}
   *
   * @since 0.5.UNRELEASED
   */
  public StructuredName structured_name
    {
      get { return this._structured_name; }
      set
        {
          ((Edsf.PersonaStore) this.store)._set_structured_name (this, value);
        }
    }

  /**
   * The e-d-s contact uid
   *
   * @since 0.5.UNRELEASED
   */
  public string contact_id { get; private set; }

  private string _full_name;
  /**
   * {@inheritDoc}
   *
   * @since 0.5.UNRELEASED
   */
  public string full_name
    {
      get { return this._full_name; }
      set
        {
          ((Edsf.PersonaStore) this.store)._set_full_name (this, value);
        }
    }

  private string _nickname;
  /**
   * {@inheritDoc}
   *
   * @since 0.5.UNRELEASED
   */
  public string nickname
    {
      get { return this._nickname; }

      set
        {
          ((Edsf.PersonaStore) this.store)._set_nickname (this, value);
        }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.5.UNRELEASED
   */
  public Gender gender { get; private set; }

  private HashSet<FieldDetails> _urls;
  private Set<FieldDetails> _urls_ro;

  /**
   * {@inheritDoc}
   *
   * @since 0.5.UNRELEASED
   */
  public Set<FieldDetails> urls
    {
      get { return this._urls_ro; }
      set
        {
          GLib.warning ("Urls setting not supported yet\n");
        }
    }

  private HashMultiMap<string, string> _im_addresses =
      new HashMultiMap<string, string> ();

  /**
   * {@inheritDoc}
   *
   * @since 0.5.UNRELEASED
   */
  public MultiMap<string, string> im_addresses
    {
      get { return this._im_addresses; }
      set
        {
          ((Edsf.PersonaStore) this.store)._set_im_addrs (this, value);
        }
    }

  private HashSet<string> _groups;
  private Set<string> _groups_ro;

  /**
   * {@inheritDoc}
   *
   * @since 0.5.UNRELEASED
   */
  public Set<string> groups
    {
      get { return this._groups_ro; }
      set
        {
          ((Edsf.PersonaStore) this.store)._set_groups (this, value);
        }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.5.UNRELEASED
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

      this.groups = new_groups;
    }

  /**
   * Build a IID.
   *
   * @param store_id the {@link PersonaStore.id}
   * @param contact the Contact
   * @return a valid IID
   *
   * @since 0.5.UNRELEASED
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
   * @since 0.5.UNRELEASED
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
   * @since 0.5.UNRELEASED
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
              gender: Gender.UNSPECIFIED,
              is_user: is_user);

      this.contact_id = contact_id;
      this._phone_numbers = new HashSet<FieldDetails> ();
      this._phone_numbers_ro = this._phone_numbers.read_only_view;
      this._email_addresses = new HashSet<FieldDetails> ();
      this._email_addresses_ro = this._email_addresses.read_only_view;
      this._notes = new HashSet<Note> ();
      this._notes_ro = this._notes.read_only_view;
      this._urls = new HashSet<FieldDetails> ();
      this._urls_ro = this._urls.read_only_view;
      this._postal_addresses = new HashSet<PostalAddress> ();
      this._postal_addresses_ro = this._postal_addresses.read_only_view;
      this._local_ids = new HashSet<string> ();
      this._local_ids_ro = this._local_ids.read_only_view;
      this._web_service_addresses = new HashMultiMap<string, string> ();
      this._groups = new HashSet<string> ();
      this._groups_ro = this._groups.read_only_view;

      this._update (contact);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.5.UNRELEASED
   */
  public override void linkable_property_to_links (string prop_name,
      Folks.Persona.LinkablePropertyCallback callback)
    {
      if (prop_name == "im-addresses")
        {
          foreach (var protocol in this._im_addresses.get_keys ())
            {
              var im_addresses = this._im_addresses.get (protocol);

              foreach (string address in im_addresses)
                  callback (protocol + ":" + address);
            }
        }
      else if (prop_name == "local-ids")
        {
          foreach (var id in this._local_ids)
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

              foreach (string address in web_service_addresses)
                  callback (web_service + ":" + address);
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
    }

  private void _update_web_services_addresses ()
    {
      this._web_service_addresses.clear ();

      var services = this.contact.get_attribute ("X-FOLKS-WEB-SERVICES-IDS");
      if (services != null)
        {
          foreach (var service in services.get_params ())
            {
              var service_name = service.get_name ().down ();
              foreach (var service_id in service.get_values ())
                {
                  this._web_service_addresses.set (service_name, service_id);
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
          var fd = new FieldDetails (attr.get_value ());
          foreach (var param in attr.get_params ())
            {
              string param_name = param.get_name ().down ();
              foreach (var param_value in param.get_values ())
                {
                  fd.add_parameter (param_name, param_value);
                }
            }
          this._email_addresses.add (fd);
        }

      this.notify_property ("email-addresses");
    }

  private void _update_notes ()
    {
      this._notes.clear ();

      string n = (string) this._get_property ("note");
      if (n != null && n != "")
        {
          var note = new Note (n);
          this._notes.add (note);
        }

      this.notify_property ("notes");
    }

  private void _update_names ()
    {
      string full_name = (string) this._get_property ("full_name");
      if (this._full_name != full_name)
        {
          this._full_name = full_name;
          this.notify_property ("full-name");
        }

      string nickname = (string) this._get_property ("nickname");
      if (this.nickname != nickname)
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
      var cache_uri = cache.build_uri_for_avatar (this.uid);

      /* Check the avatar isn't being set by our PersonaStore; if it is, just
       * notify the property and bail. This avoids circular updates to the
       * cache. */
      if (p != null &&
          p.type == ContactPhotoType.URI && p.get_uri () == cache_uri)
        {
          this.notify_property ("avatar");
          return;
        }

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

              this._avatar = new_avatar;
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
                }
              catch (GLib.Error e2)
                {
                  warning ("Couldn't cache avatar for Edsf.Persona '%s': %s",
                      this.uid, e2.message);
                  new_avatar = null; /* failure */
                }

              this._avatar = new_avatar;
              this.notify_property ("avatar");
            });
        }
    }

  private void _update_urls ()
    {
      this._urls.clear ();

      foreach (string url_property in this.url_properties)
        {
          string u = (string) this._get_property (url_property);
          if (u != null && u != "")
            {
              this._urls.add (new FieldDetails (u));
            }
        }

      this.notify_property ("urls");
    }

  private void _update_im_addresses ()
    {
      var im_eds_map = this._get_im_eds_map ();
      this._im_addresses.clear ();

      foreach (var proto in im_eds_map.get_keys ())
        {
          var addresses = this.contact.get_attributes (
              im_eds_map.lookup (proto));
          foreach (var attr in addresses)
            {
              try
                {
                  var addr = attr.get_value ();
                  string address = (owned) ImDetails.normalise_im_address (addr,
                      proto);
                  this._im_addresses.set (proto, address);
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
          var fd = new FieldDetails (attr.get_value ());
          foreach (var param in attr.get_params ())
            {
              string param_name = param.get_name ().down ();
              foreach (var param_value in param.get_values ())
                {
                  fd.add_parameter (param_name, param_value);
                }
            }
          this._phone_numbers.add (fd);
        }

     this.notify_property ("phone-numbers");
   }

  /*
   * TODO: we should check if addresses corresponding to different types
   *       are the same and if so instantiate only one PostalAddress
   *       (with the given types).
   */
  private void _update_addresses ()
    {
      this._postal_addresses.clear ();

      foreach (string afield in this.address_fields)
        {
          E.ContactAddress a =
              (E.ContactAddress) this._get_property (afield);
          if (a != null)
            {
              /* FIXME: might be my broken setup, but it looks like
               * e-d-s is ignoring the address_format param */
              var address_format = a.address_format;
              var postal_code = a.code;
              var country = a.country;
              var extension = a.ext;
              var locality = a.locality;
              var po_box = a.po;
              var region = a.region;
              var street = a.street;
              var types = new HashSet<string> ();
              types.add (afield);

              PostalAddress pa = new PostalAddress (po_box, extension, street,
                  locality, region, postal_code, country,
                  address_format, types, null);
              this._postal_addresses.add (pa);
            }
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
