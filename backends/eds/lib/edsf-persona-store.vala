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
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 *       Marco Barisione <marco.barisione@collabora.co.uk>
 *       Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 */

using E;
using Folks;
using Gee;
using GLib;

extern const string BACKEND_NAME;

/**
 * A persona store.
 * It will create {@link Persona}s for each contacts on the main addressbook.
 */
public class Edsf.PersonaStore : Folks.PersonaStore
{
  private HashMap<string, Persona> _personas;
  private Map<string, Persona> _personas_ro;
  private bool _is_prepared = false;
  private E.BookClient _addressbook;
  private E.BookClientView _ebookview;
  private string _addressbook_uri = null;
  private E.Source _source;
  private string _query_str;
  private bool _groups_supported = false;

  /**
   * The type of persona store this is.
   *
   * See {@link Folks.PersonaStore.type_id}.
   *
   * @since 0.5.UNRELEASED
   */
  public override string type_id { get { return BACKEND_NAME; } }

  private void _address_book_notify_read_only_cb (Object address_book,
      ParamSpec pspec)
    {
      this.notify_property ("can-add-personas");
      this.notify_property ("can-remove-personas");
    }

  /**
   * Whether this PersonaStore can add {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_add_personas}.
   *
   * @since 0.5.UNRELEASED
   */
  public override MaybeBool can_add_personas
    {
      get
        {
          if (this._addressbook == null)
            {
              return MaybeBool.FALSE;
            }

          return this._addressbook.readonly ? MaybeBool.FALSE : MaybeBool.TRUE;
        }
    }

  /**
   * Whether this PersonaStore can set the alias of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_alias_personas}.
   *
   * @since 0.5.UNRELEASED
   */
  public override MaybeBool can_alias_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore can set the groups of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_group_personas}.
   *
   * @since 0.5.UNRELEASED
   */
  public override MaybeBool can_group_personas
    {
      get { return this._groups_supported ? MaybeBool.TRUE : MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore can remove {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_remove_personas}.
   *
   * @since 0.5.UNRELEASED
   */
  public override MaybeBool can_remove_personas
    {
      get
        {
          if (this._addressbook == null)
            {
              return MaybeBool.FALSE;
            }

          return this._addressbook.readonly ? MaybeBool.FALSE : MaybeBool.TRUE;
        }
    }

  /**
   * Whether this PersonaStore has been prepared.
   *
   * See {@link Folks.PersonaStore.is_prepared}.
   *
   * @since 0.5.UNRELEASED
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * The {@link Persona}s exposed by this PersonaStore.
   *
   * See {@link Folks.PersonaStore.personas}.
   *
   * @since 0.5.UNRELEASED
   */
  public override Map<string, Persona> personas
    {
      get { return this._personas_ro; }
    }

  /**
   * Create a new PersonaStore.
   *
   * Create a new persona store to store the {@link Persona}s for the contacts
   *
   * @param s the e-d-s source being represented by the persona store
   *
   * @since 0.5.UNRELEASED
   */
  public PersonaStore (E.Source s)
    {
      string uri = s.peek_relative_uri ();
      Object (id: uri, display_name: uri);
      this._source = s;
      this._addressbook_uri =  uri;
      this._personas = new HashMap<string, Persona> ();
      this._personas_ro = this._personas.read_only_view;
      this._query_str = "(contains \"x-evolution-any-field\" \"\")";
    }

  ~PersonaStore ()
    {
      try
        {
          if (this._ebookview != null)
            {
              this._ebookview.objects_added.disconnect (
                  this._contacts_added_cb);
              this._ebookview.objects_removed.disconnect (
                  this._contacts_removed_cb);
              this._ebookview.objects_modified.disconnect (
                  this._contacts_changed_cb);
              this._ebookview.stop ();

              this._ebookview = null;
            }

          if (this._addressbook != null)
            {
              this._addressbook.notify["readonly"].disconnect (
                  this._address_book_notify_read_only_cb);

              this._addressbook = null;
            }
        }
      catch (GLib.Error e)
        {
          GLib.warning ("~PersonaStore: %s\n", e.message);
        }
    }

  /**
   * Add a new {@link Persona} to the PersonaStore.
   *
   * Accepted keys for `details` are:
   * - PersonaStore.detail_key (PersonaDetail.AVATAR)
   * - PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.FULL_NAME)
   * - PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.PHONE_NUMBERS)
   * - PersonaStore.detail_key (PersonaDetail.POSTAL_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.STRUCTURED_NAME)
   * - PersonaStore.detail_key (PersonaDetail.LOCAL_IDS)
   * - PersonaDetail.detail_key (PersonaDetail.WEB_SERVICE_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.NOTES)
   *
   * See {@link Folks.PersonaStore.add_persona_from_details}.
   *
   * @since 0.5.UNRELEASED
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      E.Contact contact = new E.Contact ();

      foreach (var k in details.get_keys ())
        {
          Value? v = details.lookup (k);
          if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.FULL_NAME))
            {
              contact.set (E.Contact.field_id ("full_name"),
                  v.get_string ());
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.EMAIL_ADDRESSES))
            {
              Set<FieldDetails> email_addresses =
                (Set<FieldDetails>) v.get_object ();
              yield this._set_contact_attributes (contact, email_addresses,
                  "EMAIL", E.ContactField.EMAIL);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.AVATAR))
            {
              var avatar = (File) v.get_object ();
              yield this._set_contact_avatar (contact, avatar);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.IM_ADDRESSES))
            {
              var im_addresses = (MultiMap<string, string>) v.get_object ();
              yield this._set_contact_im_addrs (contact, im_addresses);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.PHONE_NUMBERS))
            {
              Set<FieldDetails> phone_numbers =
                (Set<FieldDetails>) v.get_object ();
              yield this._set_contact_attributes (contact,
                  phone_numbers, "TEL",
                  E.ContactField.TEL);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.POSTAL_ADDRESSES))
            {
              Set<PostalAddress> postal_addresses =
                (Set<PostalAddress>) v.get_object ();
                yield this._set_contact_postal_addresses (contact,
                    postal_addresses);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.STRUCTURED_NAME))
            {
              StructuredName sname = (StructuredName) v.get_object ();
              yield this._set_contact_name (contact, sname);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.LOCAL_IDS))
            {
              Set<string> local_ids = (Set<string>) v.get_object ();
              yield this._set_contact_local_ids (contact, local_ids);
            }
          else if (k == Folks.PersonaStore.detail_key
              (PersonaDetail.WEB_SERVICE_ADDRESSES))
            {
              HashMultiMap<string, string> web_service_addresses =
                (HashMultiMap<string, string>) v.get_object ();
              yield this._set_contact_web_service_addresses (contact,
                  web_service_addresses);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.NOTES))
            {
              var notes = (Gee.HashSet<Note>) v.get_object ();
              yield this._set_contact_notes (contact, notes);
            }
        }

      Edsf.Persona? persona = null;

      try
        {
          string added_uid;
          var result = yield this._addressbook.add_contact (contact,
              out added_uid);

          if (result)
            {
              debug ("Created contact with uid: %s\n", added_uid);
              lock (this._personas)
                {
                  var iid = Edsf.Persona.build_iid (this.id, added_uid);
                  persona = this._personas.get (iid);
                  if (persona == null)
                    {
                      contact.set (E.Contact.field_id ("id"), added_uid);
                      persona = new Persona (this, contact);
                      this._personas.set (persona.iid, persona);
                      var added_personas = new HashSet<Persona> ();
                      added_personas.add (persona);
                      this._emit_personas_changed (added_personas, null);
                    }
                }
            }
          else
            {
              throw new PersonaStoreError.CREATE_FAILED
                ("BookClient.add_contact () failed.");
            }
        }
      catch (GLib.Error e)
        {
          GLib.warning ("add_persona_from_details: %s\n",
              e.message);
        }

      return persona;
    }

  /**
   * Remove a {@link Persona} from the PersonaStore.
   *
   * @param persona the that should be removed
   *
   * See {@link Folks.PersonaStore.remove_persona}.
   *
   * @since 0.5.UNRELEASED
   */
  public override async void remove_persona (Folks.Persona persona)
      throws Folks.PersonaStoreError
    {
      try
        {
          yield this._addressbook.remove_contact (
              ((Edsf.Persona) persona).contact);
        }
      catch (GLib.Error e)
        {
          /* FIXME: https://bugzilla.gnome.org/show_bug.cgi?id=652425 */
          throw new PersonaStoreError.INVALID_ARGUMENT (
              "Can't remove contact: %s\n", e.message);
        }
    }

  /**
   * Prepare the PersonaStore for use.
   *
   * TODO: we should throw different errors dependening on what went wrong
   *       when we were trying to setup the PersonaStore.
   *
   * See {@link Folks.PersonaStore.prepare}.
   *
   * @since 0.5.UNRELEASED
   */
  public override async void prepare () throws PersonaStoreError
    {
      /* FIXME: https://bugzilla.gnome.org/show_bug.cgi?id=652637 */
      lock (this._is_prepared)
        {
          if (this._is_prepared)
            {
              return;
            }

          /* FIXME: we need better error codes */

          try
            {
              this._addressbook = new E.BookClient (this._source);
            }
          catch (GLib.Error e1)
            {
              throw new PersonaStoreError.INVALID_ARGUMENT (
                  "Couldn't get BookClient: %s\n", e1.message);
            }

          this._addressbook.notify["readonly"].connect (
              this._address_book_notify_read_only_cb);

          try
            {
              yield this._addressbook.open (true, null);
            }
          catch (GLib.Error e2)
            {
              throw new PersonaStoreError.INVALID_ARGUMENT (
                  "Couldn't open addressbook: %s\n", e2.message);
            }

          if (this._addressbook.is_opened () == false)
            {
              throw new PersonaStoreError.INVALID_ARGUMENT (
                  "Couldn't open addressbook\n");
            }

          /* Determine which fields the address book supports. This is necessary
           * to work out whether we can support groups. */
          string supported_fields;
          try
            {
              yield this._addressbook.get_backend_property ("supported-fields",
                  out supported_fields, null);

              /* We get a comma-separated list of fields back. */
              if (supported_fields != null)
                {
                  string[] fields = supported_fields.split (",");

                  this._groups_supported =
                      (Contact.field_name (ContactField.CATEGORIES) in fields);
                }
            }
          catch (GLib.Error e5)
            {
              throw new PersonaStoreError.INVALID_ARGUMENT (
                  "Couldn't get address book capabilities: %s", e5.message);
            }

          bool got_view = false;
          try
            {
              got_view = yield this._addressbook.get_view (this._query_str,
                  out this._ebookview);
            }
          catch (GLib.Error e3)
            {
              throw new PersonaStoreError.INVALID_ARGUMENT (
                  "Couldn't get book view: %s\n", e3.message);
            }

          if (got_view == false)
            {
              throw new PersonaStoreError.INVALID_ARGUMENT (
                  "Couldn't get book view\n");
            }

          this._ebookview.objects_added.connect (this._contacts_added_cb);
          this._ebookview.objects_removed.connect (this._contacts_removed_cb);
          this._ebookview.objects_modified.connect (this._contacts_changed_cb);

          try
            {
              this._ebookview.start ();
            }
          catch (GLib.Error e4)
            {
              throw new PersonaStoreError.INVALID_ARGUMENT (
                  "Couldn't start bookview: %s\n", e4.message);
            }

          this._is_prepared = true;
          this.notify_property ("is-prepared");
        }
    }

  internal async void _set_avatar (Edsf.Persona persona, File avatar)
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_avatar (contact, avatar);
          yield this._addressbook.modify_contact (contact);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Can't update avatar: %s\n", e.message);
        }
    }

  internal async void _set_web_service_addresses (Edsf.Persona persona,
      MultiMap<string, string> web_service_addresses)
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_web_service_addresses (contact,
            web_service_addresses);
          yield this._addressbook.modify_contact (contact);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Can't set local IDS: %s\n", e.message);
        }
    }

  private async void _set_contact_web_service_addresses (E.Contact contact,
      MultiMap<string, string> web_service_addresses)
    {
      var attr = contact.get_attribute ("X-FOLKS-WEB-SERVICES-IDS");
      if (attr != null)
        {
          contact.remove_attribute (attr);
        }

      var attr_n = new VCardAttribute (null, "X-FOLKS-WEB-SERVICES-IDS");
      foreach (var service in web_service_addresses.get_keys ())
        {
          var param = new E.VCardAttributeParam (service);
          foreach (var id in web_service_addresses.get (service))
            {
              param.add_value (id);
            }
          attr_n.add_param (param);
        }
      contact.add_attribute (attr_n);
    }

  internal async void _set_local_ids (Edsf.Persona persona,
      Set<string> local_ids)
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_local_ids (contact, local_ids);
          yield this._addressbook.modify_contact (contact);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Can't set local IDS: %s\n", e.message);
        }
    }

  private async void _set_contact_local_ids (E.Contact contact,
      Set<string> local_ids)
    {
      var attr = contact.get_attribute ("X-FOLKS-CONTACTS-IDS");
      if (attr != null)
        {
          contact.remove_attribute (attr);
        }

      attr = new VCardAttribute (null, "X-FOLKS-CONTACTS-IDS");
      foreach (var local_id in local_ids)
        {
          attr.add_value (local_id);
        }

      contact.add_attribute (attr);
    }

  private async void _set_contact_avatar (E.Contact contact,
      File avatar)
    {
      try
        {
          uint8[] photo_content;
          yield avatar.load_contents_async (null, out photo_content);

          var cp = new ContactPhoto ();
          cp.type = ContactPhotoType.INLINED;
          cp.set_inlined (photo_content);

          contact.set (E.Contact.field_id ("photo"), cp);
        }
      catch (GLib.Error e_avatar)
        {
          GLib.warning ("Can't load avatar %s: %s\n\n", avatar.get_path (),
              e_avatar.message);
        }
    }

  internal async void _set_emails (Edsf.Persona persona,
      Set<FieldDetails> emails)
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_attributes (contact, emails, "EMAIL",
              E.ContactField.EMAIL);
          yield this._addressbook.modify_contact (contact);
        }
      catch (GLib.Error error)
        {
          GLib.warning ("Can't update email-addresses: %s\n",
              error.message);
        }
    }

  internal async void _set_phones (Edsf.Persona persona,
      Set<FieldDetails> phones)
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_attributes (contact, phones, "TEL",
              E.ContactField.TEL);
          yield this._addressbook.modify_contact (contact);
        }
      catch (GLib.Error error)
        {
          GLib.warning ("Can't update phones: %s\n", error.message);
        }
    }

  internal async void _set_postal_addresses (Edsf.Persona persona,
      Set<PostalAddress> addresses)
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_postal_addresses (contact,
              addresses);
          yield this._addressbook.modify_contact (contact);
        }
      catch (GLib.Error error)
        {
          GLib.warning ("Can't update postal addresses: %s\n",
              error.message);
        }
    }

  private async void _set_contact_postal_addresses (E.Contact contact,
      Set<PostalAddress> addresses)
    {
      foreach (var pa in addresses)
        {
          var address = new E.ContactAddress ();

          address.po = pa.po_box;
          address.ext = pa.extension;
          address.street = pa.street;
          address.locality = pa.locality;
          address.region = pa.region;
          address.code = pa.postal_code;
          address.country = pa.country;
          address.address_format = pa.address_format;

          if (pa.types.size > 0)
            {
              var pa_type = pa.types.to_array ()[0];
              contact.set (E.Contact.field_id (pa_type), address);
            }
          else
            {
              contact.set (E.ContactField.ADDRESS_OTHER, address);
            }
        }
    }

  private async void _set_contact_attributes (E.Contact contact,
      Set<FieldDetails> new_attributes,
      string attrib_name, E.ContactField field_id)
    {
      var attributes = new GLib.List <E.VCardAttribute>();

      foreach (var e in new_attributes)
        {
          var attr = new E.VCardAttribute (null, attrib_name);
          attr.add_value (e.value);
          foreach (var param_name in e.parameters.get_keys ())
            {
              var param = new E.VCardAttributeParam (param_name.up ());
              foreach (var param_val in e.parameters.get (param_name))
                {
                  param.add_value (param_val);
                }
              attr.add_param (param);
            }
          attributes.prepend (attr);
        }

      contact.set_attributes (field_id, attributes);
    }

  internal async void _set_full_name (Edsf.Persona persona,
      string full_name)
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          contact.set (E.Contact.field_id ("full_name"), full_name);
          yield this._addressbook.modify_contact (contact);
        }
      catch (GLib.Error error)
        {
          GLib.warning ("Can't update full name: %s\n", error.message);
        }
    }

  internal async void _set_nickname (Edsf.Persona persona, string nickname)
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          contact.set (E.Contact.field_id ("nickname"), nickname);
          yield this._addressbook.modify_contact (contact);
        }
      catch (GLib.Error error)
        {
          GLib.warning ("Can't update nickname: %s\n", error.message);
        }
    }

  internal async void _set_notes (Edsf.Persona persona,
      Set<Note> notes)
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_notes (contact, notes);
          yield this._addressbook.modify_contact (contact);
        }
      catch (GLib.Error error)
        {
          GLib.warning ("Can't update notes: %s\n", error.message);
        }
    }

  private async void _set_contact_notes (E.Contact contact, Set<Note> notes)
    {
      string note_str = "";
      foreach (var note in notes)
        {
          if (note_str != "")
            {
              note_str += ". ";
            }
          note_str += note.content;
        }

      contact.set (E.Contact.field_id ("note"), note_str);
    }

  internal async void _set_structured_name (Edsf.Persona persona,
      StructuredName sname)
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_name (contact, sname);
          yield this._addressbook.modify_contact (contact);
        }
      catch (GLib.Error error)
        {
          GLib.warning ("Can't update structured name: %s\n", error.message);
        }
    }

  private async void _set_contact_name (E.Contact contact,
      StructuredName sname)
    {
      E.ContactName contact_name = new E.ContactName ();

      contact_name.family = sname.family_name;
      contact_name.given = sname.given_name;
      contact_name.additional = sname.additional_names;
      contact_name.suffixes = sname.suffixes;
      contact_name.prefixes = sname.prefixes;

      contact.set (E.Contact.field_id ("name"), contact_name);
    }

  internal async void _set_im_addrs  (Edsf.Persona persona,
      MultiMap<string, string> im_addrs)
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_im_addrs (contact, im_addrs);
          yield this._addressbook.modify_contact (contact);
        }
      catch (GLib.Error error)
        {
          GLib.warning ("Can't update IM addresses: %s\n", error.message);
        }
    }

  /* TODO: this could be smarter & more efficient. */
  private async void _set_contact_im_addrs (E.Contact contact,
      MultiMap<string, string> im_addrs)
    {
      var im_eds_map = Edsf.Persona._get_im_eds_map ();

      /* First let's remove everything */
      foreach (var field_id in im_eds_map.get_values ())
        {
          var attrs = contact.get_attributes (field_id);
          foreach (var attr in attrs)
            {
              contact.remove_attribute (attr);
            }
        }

     foreach (var proto in im_addrs.get_keys ())
       {
         var attributes = new GLib.List <E.VCardAttribute>();
         var attrib_name = ("X-" + proto).up ();
         bool added = false;

         foreach (var im in im_addrs.get (proto))
           {
             var attr_n = new E.VCardAttribute (null, attrib_name);
             attr_n.add_value (im);
             attributes.prepend (attr_n);
             added = true;
           }

         if (added)
           {
             var field_id_t = im_eds_map.lookup (proto);
             contact.set_attributes (field_id_t, attributes);
           }
       }
    }

  internal async void _set_groups (Edsf.Persona persona,
      Set<string> groups)
    {
      if (this._groups_supported == false)
        {
          /* Give up. */
          return;
        }

      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_groups (contact, groups);
          yield this._addressbook.modify_contact (contact);
        }
      catch (GLib.Error error)
        {
          GLib.warning ("Can't update groups: %s\n", error.message);
        }
    }

  private async void _set_contact_groups (E.Contact contact, Set<string> groups)
    {
      var categories = new GLib.List<string> ();

      foreach (var group in groups)
        {
          if (group == "")
            {
              continue;
            }

          categories.prepend (group);
        }

      contact.set (ContactField.CATEGORY_LIST, categories);
    }

  private void _contacts_added_cb (GLib.List<E.Contact> contacts)
    {
      var added_personas = new HashSet<Persona> ();
      lock (this._personas)
        {
          foreach (E.Contact c in contacts)
            {
              var iid = Edsf.Persona.build_iid_from_contact (this.id, c);
              var persona = this._personas.get (iid);
              if (persona == null)
                {
                  persona = new Persona (this, c);
                  this._personas.set (persona.iid, persona);
                  added_personas.add (persona);
                }
            }
        }

      if (added_personas.size > 0)
        {
          this._emit_personas_changed (added_personas, null);
        }
    }

  private void _contacts_changed_cb (GLib.List<E.Contact> contacts)
    {
      foreach (E.Contact c in contacts)
        {
          var iid = Edsf.Persona.build_iid_from_contact (this.id, c);
          var persona = this._personas.get (iid);
          if (persona != null)
            {
              persona._update (c);
            }
        }
    }

  private void _contacts_removed_cb (GLib.List<string> contacts_ids)
    {
      var removed_personas = new HashSet<Persona> ();

      foreach (string contact_id in contacts_ids)
        {
          var iid = Edsf.Persona.build_iid (this.id, contact_id);
          var persona = _personas.get (iid);
          if (persona != null)
            {
              removed_personas.add (persona);
              this._personas.unset (persona.iid);
            }
        }

       if (removed_personas.size > 0)
         {
           this._emit_personas_changed (null, removed_personas);
         }
    }
}
