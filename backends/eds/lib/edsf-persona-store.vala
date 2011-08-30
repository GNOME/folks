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

  private const string[] _always_writeable_properties =
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

  /**
   * The type of persona store this is.
   *
   * See {@link Folks.PersonaStore.type_id}.
   *
   * @since 0.6.0
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
   * @since 0.6.0
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
   * @since 0.6.0
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
   * @since 0.6.0
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
   * @since 0.6.0
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
   * @since 0.6.0
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public override string[] always_writeable_properties
    {
      get { return this._always_writeable_properties; }
    }

  /**
   * The {@link Persona}s exposed by this PersonaStore.
   *
   * See {@link Folks.PersonaStore.personas}.
   *
   * @since 0.6.0
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
   * @since 0.6.0
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
      this.trust_level = PersonaStoreTrust.PARTIAL;
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
   * - PersonaStore.detail_key (PersonaDetail.GENDER)
   * - PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.PHONE_NUMBERS)
   * - PersonaStore.detail_key (PersonaDetail.POSTAL_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.STRUCTURED_NAME)
   * - PersonaStore.detail_key (PersonaDetail.LOCAL_IDS)
   * - PersonaStore.detail_key (PersonaDetail.WEB_SERVICE_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.NOTES)
   * - PersonaStore.detail_key (PersonaDetail.URL)
   *
   * See {@link Folks.PersonaStore.add_persona_from_details}.
   *
   * @since 0.6.0
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
              Set<EmailFieldDetails> email_addresses =
                (Set<EmailFieldDetails>) v.get_object ();
              yield this._set_contact_attributes_string (contact,
                  email_addresses,
                  "EMAIL", E.ContactField.EMAIL);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.AVATAR))
            {
              try
                {
                  var avatar = (LoadableIcon?) v.get_object ();
                  yield this._set_contact_avatar (contact, avatar);
                }
              catch (PropertyError e1)
                {
                  warning ("Couldn't set avatar on the EContact: %s",
                      e1.message);
                }
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.IM_ADDRESSES))
            {
              var im_fds = (MultiMap<string, ImFieldDetails>) v.get_object ();
              yield this._set_contact_im_fds (contact, im_fds);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.PHONE_NUMBERS))
            {
              Set<PhoneFieldDetails> phone_numbers =
                (Set<PhoneFieldDetails>) v.get_object ();
              yield this._set_contact_attributes_string (contact,
                  phone_numbers, "TEL",
                  E.ContactField.TEL);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.POSTAL_ADDRESSES))
            {
              Set<PostalAddressFieldDetails> postal_fds =
                (Set<PostalAddressFieldDetails>) v.get_object ();
                yield this._set_contact_postal_addresses (contact,
                    postal_fds);
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
              HashMultiMap<string, WebServiceFieldDetails>
                web_service_addresses =
                (HashMultiMap<string, WebServiceFieldDetails>) v.get_object ();
              yield this._set_contact_web_service_addresses (contact,
                  web_service_addresses);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.NOTES))
            {
              var notes = (Gee.HashSet<NoteFieldDetails>) v.get_object ();
              yield this._set_contact_notes (contact, notes);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.GENDER))
            {
              var gender = (Gender) v.get_enum ();
              yield this._set_contact_gender (contact, gender);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.URLS))
            {
              Set<UrlFieldDetails> urls = (Set<UrlFieldDetails>) v.get_object ();
              yield this._set_contact_urls (contact, urls);
            }
        }

      Edsf.Persona? persona = null;

      try
        {
          string added_uid;
          var result = yield this._addressbook.add_contact (contact,
              null,
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
   * See {@link Folks.PersonaStore.remove_persona}.
   *
   * @param persona the persona that should be removed
   *
   * @since 0.6.0
   */
  public override async void remove_persona (Folks.Persona persona)
      throws Folks.PersonaStoreError
    {
      try
        {
          yield this._addressbook.remove_contact (
              ((Edsf.Persona) persona).contact, null);
        }
      catch (GLib.Error e)
        {
          if (e.domain == BookClient.error_quark ())
            {
              switch ((BookClientError) e.code)
                {
                  case BookClientError.CONTACT_NOT_FOUND:
                    /* Not an error, since we've got nothing to do! */
                    return;
                  /* We don't expect to receive any of the error codes below: */
                  case BookClientError.NO_SUCH_BOOK:
                  case BookClientError.CONTACT_ID_ALREADY_EXISTS:
                  case BookClientError.NO_SUCH_SOURCE:
                  case BookClientError.NO_SPACE:
                  default:
                    /* Fall out */
                    break;
                }
            }
          else if (e.domain == Client.error_quark ())
            {
              switch ((ClientError) e.code)
                {
                  case ClientError.REPOSITORY_OFFLINE:
                    throw new PersonaStoreError.STORE_OFFLINE (
                        /* Translators: the first parameter is an address book
                         * URI and the second is a persona UID. */
                        _("Address book ‘%s’ is offline, so contact ‘%s’ cannot be removed."),
                            this.id, persona.uid);
                  case ClientError.PERMISSION_DENIED:
                    throw new PersonaStoreError.PERMISSION_DENIED (
                        /* Translators: the first parameter is an address book
                         * URI and the second is an error message. */
                        _("Permission denied to remove contact ‘%s’: %s"),
                        persona.uid, e.message);
                  case ClientError.NOT_SUPPORTED:
                    throw new PersonaStoreError.READ_ONLY (
                        /* Translators: the parameter is an error message. */
                        _("Removing contacts isn't supported by this persona store: %s"),
                            e.message);
                  case ClientError.AUTHENTICATION_REQUIRED:
                    /* TODO: Support authentication. bgo#653339 */
                  /* We expect to receive these, but they don't need special
                   * error codes: */
                  case ClientError.INVALID_ARG:
                  case ClientError.BUSY:
                  case ClientError.DBUS_ERROR:
                  case ClientError.OTHER_ERROR:
                    /* Fall through. */
                  /* We don't expect to receive any of the error codes below: */
                  case ClientError.COULD_NOT_CANCEL:
                  case ClientError.AUTHENTICATION_FAILED:
                  case ClientError.TLS_NOT_AVAILABLE:
                  case ClientError.OFFLINE_UNAVAILABLE:
                  case ClientError.UNSUPPORTED_AUTHENTICATION_METHOD:
                  case ClientError.SEARCH_SIZE_LIMIT_EXCEEDED:
                  case ClientError.SEARCH_TIME_LIMIT_EXCEEDED:
                  case ClientError.INVALID_QUERY:
                  case ClientError.QUERY_REFUSED:
                  default:
                    /* Fall out */
                    break;
                }
            }

          /* Fallback error. */
          throw new PersonaStoreError.REMOVE_FAILED (
              _("Can't remove contact ‘%s’: %s"), persona.uid, e.message);
        }
    }

  /**
   * Prepare the PersonaStore for use.
   *
   * See {@link Folks.PersonaStore.prepare}.
   *
   * @since 0.6.0
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

          try
            {
              this._addressbook = new E.BookClient (this._source);

              this._addressbook.notify["readonly"].connect (
                  this._address_book_notify_read_only_cb);

              yield this._addressbook.open (true, null);
            }
          catch (GLib.Error e1)
            {
              if (e1.domain == BookClient.error_quark ())
                {
                  switch ((BookClientError) e1.code)
                    {
                      /* We don't expect to receive any of the error codes
                       * below: */
                      case BookClientError.NO_SUCH_BOOK:
                      case BookClientError.NO_SUCH_SOURCE:
                      case BookClientError.CONTACT_NOT_FOUND:
                      case BookClientError.CONTACT_ID_ALREADY_EXISTS:
                      case BookClientError.NO_SPACE:
                      default:
                        /* Fall out */
                        break;
                    }
                }
              else if (e1.domain == Client.error_quark ())
                {
                  switch ((ClientError) e1.code)
                    {
                      case ClientError.REPOSITORY_OFFLINE:
                        throw new PersonaStoreError.STORE_OFFLINE (
                            /* Translators: the parameter is an address book
                             * URI. */
                            _("Address book ‘%s’ is offline."), this.id);
                      case ClientError.PERMISSION_DENIED:
                        throw new PersonaStoreError.PERMISSION_DENIED (
                            /* Translators: the first parameter is an address
                             * book URI and the second is an error message. */
                            _("Permission denied to open address book ‘%s’: %s"),
                            this.id, e1.message);
                      case ClientError.AUTHENTICATION_REQUIRED:
                        /* TODO: Support authentication. bgo#653339 */
                      /* We expect to receive these, but they don't need special
                       * error codes: */
                      case ClientError.NOT_SUPPORTED:
                      case ClientError.INVALID_ARG:
                      case ClientError.BUSY:
                      case ClientError.DBUS_ERROR:
                      case ClientError.OTHER_ERROR:
                        /* Fall through. */
                      /* We don't expect to receive any of the error codes
                       * below: */
                      case ClientError.COULD_NOT_CANCEL:
                      case ClientError.AUTHENTICATION_FAILED:
                      case ClientError.TLS_NOT_AVAILABLE:
                      case ClientError.OFFLINE_UNAVAILABLE:
                      case ClientError.UNSUPPORTED_AUTHENTICATION_METHOD:
                      case ClientError.SEARCH_SIZE_LIMIT_EXCEEDED:
                      case ClientError.SEARCH_TIME_LIMIT_EXCEEDED:
                      case ClientError.INVALID_QUERY:
                      case ClientError.QUERY_REFUSED:
                      default:
                        /* Fall out */
                        break;
                    }
                }

              /* Fallback error */
              throw new PersonaStoreError.INVALID_ARGUMENT (
                  /* Translators: the first parameter is an address book URI
                   * and the second is an error message. */
                  _("Couldn't open address book ‘%s’: %s"), this.id, e1.message);
            }

          if (this._addressbook.is_opened () == false)
            {
              throw new PersonaStoreError.INVALID_ARGUMENT (
                  /* Translators: the parameter is an address book URI. */
                  _("Couldn't open address book ‘%s’."), this.id);
            }

          /* Determine which fields the address book supports. This is necessary
           * to work out whether we can support groups. */
          string supported_fields;
          try
            {
              yield this._addressbook.get_backend_property ("supported-fields",
                  null, out supported_fields);

              /* We get a comma-separated list of fields back. */
              if (supported_fields != null)
                {
                  string[] fields = supported_fields.split (",");

                  this._groups_supported =
                      (Contact.field_name (ContactField.CATEGORIES) in fields);
                }
            }
          catch (GLib.Error e2)
            {
              throw new PersonaStoreError.INVALID_ARGUMENT (
                  /* Translators: the parameteter is an error message. */
                  _("Couldn't get address book capabilities: %s"), e2.message);
            }

          bool got_view = false;
          try
            {
              got_view = yield this._addressbook.get_view (this._query_str,
                  null, out this._ebookview);

              if (got_view == false)
                {
                  throw new PersonaStoreError.INVALID_ARGUMENT (
                      /* Translators: the parameter is an address book URI. */
                      _("Couldn't get view for address book ‘%s’."),
                          this.id);
                }

              this._ebookview.objects_added.connect (this._contacts_added_cb);
              this._ebookview.objects_removed.connect (this._contacts_removed_cb);
              this._ebookview.objects_modified.connect (this._contacts_changed_cb);

              this._ebookview.start ();
            }
          catch (GLib.Error e3)
            {
              if (e3.domain == BookClient.error_quark ())
                {
                  switch ((BookClientError) e3.code)
                    {
                      /* We don't expect to receive any of the error codes
                       * below: */
                      case BookClientError.NO_SUCH_BOOK:
                      case BookClientError.NO_SUCH_SOURCE:
                      case BookClientError.CONTACT_NOT_FOUND:
                      case BookClientError.CONTACT_ID_ALREADY_EXISTS:
                      case BookClientError.NO_SPACE:
                      default:
                        /* Fall out */
                        break;
                    }
                }
              else if (e3.domain == Client.error_quark ())
                {
                  switch ((ClientError) e3.code)
                    {
                      case ClientError.REPOSITORY_OFFLINE:
                        throw new PersonaStoreError.STORE_OFFLINE (
                            /* Translators: the parameter is an address book
                             * URI. */
                            _("Address book ‘%s’ is offline."), this.id);
                      case ClientError.PERMISSION_DENIED:
                        throw new PersonaStoreError.PERMISSION_DENIED (
                            /* Translators: the first parameter is an address
                             * book URI and the second is an error message. */
                            _("Permission denied to open address book ‘%s’: %s"),
                            this.id, e3.message);
                      case ClientError.AUTHENTICATION_REQUIRED:
                        /* TODO: Support authentication. bgo#653339 */
                      /* We expect to receive these, but they don't need special
                       * error codes: */
                      case ClientError.NOT_SUPPORTED:
                      case ClientError.INVALID_ARG:
                      case ClientError.BUSY:
                      case ClientError.DBUS_ERROR:
                      case ClientError.OTHER_ERROR:
                      case ClientError.SEARCH_SIZE_LIMIT_EXCEEDED:
                      case ClientError.SEARCH_TIME_LIMIT_EXCEEDED:
                      case ClientError.QUERY_REFUSED:
                        /* Fall through. */
                      /* We don't expect to receive any of the error codes
                       * below: */
                      case ClientError.COULD_NOT_CANCEL:
                      case ClientError.AUTHENTICATION_FAILED:
                      case ClientError.TLS_NOT_AVAILABLE:
                      case ClientError.OFFLINE_UNAVAILABLE:
                      case ClientError.UNSUPPORTED_AUTHENTICATION_METHOD:
                      case ClientError.INVALID_QUERY:
                      default:
                        /* Fall out */
                        break;
                    }
                }

              /* Fallback error */
              throw new PersonaStoreError.INVALID_ARGUMENT (
                  /* Translators: the first parameter is an address book URI
                   * and the second is an error message. */
                  _("Couldn't get view for address book ‘%s’: %s"),
                  this.id, e3.message);
            }

          this._is_prepared = true;
          this.notify_property ("is-prepared");
        }
    }

  internal async void _set_avatar (Edsf.Persona persona, LoadableIcon? avatar)
      throws PropertyError
    {
      /* Return early if there will be no change */
      if ((persona.avatar == null && avatar == null) ||
          (persona.avatar != null && persona.avatar.equal (avatar)))
        {
          return;
        }

      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_avatar (contact, avatar);
          yield this._addressbook.modify_contact (contact, null);
        }
      catch (PropertyError e1)
        {
          throw e1;
        }
      catch (GLib.Error e2)
        {
          throw this.e_client_error_to_property_error ("avatar", e2);
        }
    }

  internal async void _set_web_service_addresses (Edsf.Persona persona,
      MultiMap<string, WebServiceFieldDetails> web_service_addresses)
    {
      if (Utils.multi_map_str_afd_equal (persona.web_service_addresses,
            web_service_addresses))
        return;

      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_web_service_addresses (contact,
            web_service_addresses);
          yield this._addressbook.modify_contact (contact, null);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Can't set local IDS: %s\n", e.message);
        }
    }

  private async void _set_contact_web_service_addresses (E.Contact contact,
      MultiMap<string, WebServiceFieldDetails> web_service_addresses)
    {
      unowned VCardAttribute attr =
          contact.get_attribute ("X-FOLKS-WEB-SERVICES-IDS");
      if (attr != null)
        {
          contact.remove_attribute (attr);
        }

      var attr_n = new VCardAttribute (null, "X-FOLKS-WEB-SERVICES-IDS");
      foreach (var service in web_service_addresses.get_keys ())
        {
          var param = new E.VCardAttributeParam (service);
          foreach (var ws_fd in web_service_addresses.get (service))
            {
              param.add_value (ws_fd.value);
            }
          attr_n.add_param (param);
        }
      contact.add_attribute ((owned) attr_n);
    }

  internal async void _set_urls (Edsf.Persona persona,
      Set<UrlFieldDetails> urls)
    {
      if (Utils.set_afd_equal (persona.urls, urls))
        return;

      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_urls (contact, urls);
          yield this._addressbook.modify_contact (contact, null);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Can't set urls: %s", e.message);
        }
    }

  private async void _set_contact_urls (E.Contact contact,
      Set<UrlFieldDetails> urls)
    {
      var vcard = (E.VCard) contact;
      vcard.remove_attributes (null, "X-URIS");

      foreach (var u in urls)
        {
          bool homepage = false;
          bool blog = false;
          bool fburl = false;
          bool video = false;

          var attr = new E.VCardAttribute (null, "X-URIS");
          attr.add_value (u.value);
          foreach (var param_name in u.parameters.get_keys ())
            {
              var param = new E.VCardAttributeParam (param_name.up ());
              foreach (var param_val in u.parameters.get (param_name))
                {
                  if (param_name == "type")
                    {
                      /* Keep in sync with Edsf.Persona.url_properties */
                      if (param_val == "homepage_url")
                        {
                          homepage = true;
                        }
                      else if (param_val == "blog_url")
                        {
                          blog = true;
                        }
                      else if (param_val == "fburl")
                        {
                          fburl = true;
                        }
                      else if (param_val == "video_url")
                        {
                          video = true;
                        }
                    }
                  param.add_value (param_val);
                }
              attr.add_param (param);
            }

          if (homepage)
            {
              contact.set (E.Contact.field_id ("homepage_url"), u.value);
            }
          else if (blog)
            {
              contact.set (E.Contact.field_id ("blog_url"), u.value);
            }
          else if (fburl)
            {
              contact.set (E.Contact.field_id ("fburl"), u.value);
            }
          else if (video)
            {
              contact.set (E.Contact.field_id ("video_url"), u.value);
            }
          else
            {
              contact.add_attribute ((owned) attr);
            }
        }
    }

  internal async void _set_local_ids (Edsf.Persona persona,
      Set<string> local_ids) throws PropertyError
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_local_ids (contact, local_ids);
          yield this._addressbook.modify_contact (contact, null);
        }
      catch (GLib.Error e)
        {
          throw this.e_client_error_to_property_error ("local-ids", e);
        }
    }

  private async void _set_contact_local_ids (E.Contact contact,
      Set<string> local_ids)
    {
      unowned VCardAttribute attr =
          contact.get_attribute ("X-FOLKS-CONTACTS-IDS");
      if (attr != null)
        {
          contact.remove_attribute (attr);
        }

      var new_attr = new VCardAttribute (null, "X-FOLKS-CONTACTS-IDS");
      foreach (var local_id in local_ids)
        {
          new_attr.add_value (local_id);
        }

      contact.add_attribute ((owned) new_attr);
    }

  private async void _set_contact_avatar (E.Contact contact,
      LoadableIcon? avatar) throws PropertyError
    {
      if (avatar == null)
        {
          unowned VCardAttribute attr = contact.get_attribute ("PHOTO");
          if (attr != null)
            {
              contact.remove_attribute (attr);
            }
        }
      else
        {
          try
            {
              /* Set the avatar on the contact */
              var cp = new ContactPhoto ();
              cp.type = ContactPhotoType.INLINED;
              var input_s = yield avatar.load_async (-1, null, null);

              uint8[] image_data = new uint8[0];
              uint8[] buffer = new uint8[4096];
              while (true)
                {
                  var size_read = yield input_s.read_async (buffer);
                  if (size_read <= 0)
                    {
                      break;
                    }
                  var read_cur = image_data.length;
                  image_data.resize (read_cur + (int)size_read);
                  Memory.copy (&image_data[read_cur], buffer, size_read);
                }

              cp.set_inlined (image_data);
              contact.set (ContactField.PHOTO, cp);
            }
          catch (GLib.Error e1)
            {
              /* Loading/Reading the avatar failed. */
              throw new PropertyError.INVALID_VALUE (
                  /* Translators: the parameter is an error message. */
                  _("Can't update avatar: %s"), e1.message);
            }
        }
    }

  internal async void _set_emails (Edsf.Persona persona,
      Set<EmailFieldDetails> emails) throws PropertyError
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_attributes_string (contact, emails, "EMAIL",
              E.ContactField.EMAIL);
          yield this._addressbook.modify_contact (contact, null);
        }
      catch (GLib.Error e)
        {
          throw this.e_client_error_to_property_error ("email-addresses", e);
        }
    }

  internal async void _set_phones (Edsf.Persona persona,
      Set<PhoneFieldDetails> phones) throws PropertyError
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_attributes_string (contact, phones, "TEL",
              E.ContactField.TEL);
          yield this._addressbook.modify_contact (contact, null);
        }
      catch (GLib.Error e)
        {
          throw this.e_client_error_to_property_error ("phone-numbers", e);
        }
    }

  internal async void _set_postal_addresses (Edsf.Persona persona,
      Set<PostalAddressFieldDetails> postal_fds)
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_postal_addresses (contact,
              postal_fds);
          yield this._addressbook.modify_contact (contact, null);
        }
      catch (GLib.Error error)
        {
          GLib.warning ("Can't update postal addresses: %s\n",
              error.message);
        }
    }

  private async void _set_contact_postal_addresses (E.Contact contact,
      Set<PostalAddressFieldDetails> postal_fds)
    {
      yield this._set_contact_attributes<PostalAddress> (contact,
          postal_fds,
          (attr, address) => {
            attr.add_value (address.po_box);
            attr.add_value (address.extension);
            attr.add_value (address.street);
            attr.add_value (address.locality);
            attr.add_value (address.region);
            attr.add_value (address.postal_code);
            attr.add_value (address.country);
          },
          "ADR", E.ContactField.ADDRESS);
    }

  delegate void FieldToAttribute<T> (E.VCardAttribute attr, T value);

  private async void _set_contact_attributes<T> (E.Contact contact,
      Set<AbstractFieldDetails<T>> new_attributes,
      FieldToAttribute<T> fill_attribute,
      string attrib_name, E.ContactField field_id)
    {
      var attributes = new GLib.List <E.VCardAttribute>();

      foreach (var e in new_attributes)
        {
          var attr = new E.VCardAttribute (null, attrib_name);
          fill_attribute (attr, e.value);
          foreach (var param_name in e.parameters.get_keys ())
            {
              var param = new E.VCardAttributeParam (param_name.up ());
              foreach (var param_val in e.parameters.get (param_name))
                {
                  param.add_value (param_val);
                }
              attr.add_param (param);
            }
          attributes.prepend ((owned) attr);
        }

      contact.set_attributes (field_id, attributes);
    }

  private async void _set_contact_attributes_string (E.Contact contact,
      Set<AbstractFieldDetails<string>> new_attributes,
      string attrib_name, E.ContactField field_id)
    {
      _set_contact_attributes<string> (contact, new_attributes,
          (attr, value) => { attr.add_value (value); },
          attrib_name, field_id);
    }

  internal async void _set_full_name (Edsf.Persona persona,
      string full_name) throws PropertyError
    {
      if (persona.full_name == full_name)
        return;

      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          contact.set (E.Contact.field_id ("full_name"), full_name);
          yield this._addressbook.modify_contact (contact, null);
        }
      catch (GLib.Error e)
        {
          throw this.e_client_error_to_property_error ("full-name", e);
        }
    }

  internal async void _set_nickname (Edsf.Persona persona, string nickname)
      throws PropertyError
    {
      if (persona.nickname == nickname)
        return;

      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          contact.set (E.Contact.field_id ("nickname"), nickname);
          yield this._addressbook.modify_contact (contact, null);
        }
      catch (GLib.Error e)
        {
          throw this.e_client_error_to_property_error ("nickname", e);
        }
    }

  internal async void _set_notes (Edsf.Persona persona,
      Set<NoteFieldDetails> notes) throws PropertyError
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_notes (contact, notes);
          yield this._addressbook.modify_contact (contact, null);
        }
      catch (GLib.Error e)
        {
          throw this.e_client_error_to_property_error ("notes", e);
        }
    }

  private async void _set_contact_notes (E.Contact contact,
      Set<NoteFieldDetails> notes)
    {
      string note_str = "";
      foreach (var note in notes)
        {
          if (note_str != "")
            {
              note_str += ". ";
            }
          note_str += note.value;
        }

      contact.set (E.Contact.field_id ("note"), note_str);
    }

  internal async void _set_structured_name (Edsf.Persona persona,
      StructuredName? sname) throws PropertyError
    {
      if (persona.structured_name != null &&
          persona.structured_name.equal (sname))
        return;

      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_name (contact, sname);
          yield this._addressbook.modify_contact (contact, null);
        }
      catch (GLib.Error e)
        {
          throw this.e_client_error_to_property_error ("structured-name", e);
        }
    }

  private async void _set_contact_name (E.Contact contact,
      StructuredName? sname)
    {
      E.ContactName contact_name = new E.ContactName ();

      if (sname != null)
        {
          contact_name.family = sname.family_name;
          contact_name.given = sname.given_name;
          contact_name.additional = sname.additional_names;
          contact_name.suffixes = sname.suffixes;
          contact_name.prefixes = sname.prefixes;
        }

      contact.set (E.Contact.field_id ("name"), contact_name);
    }

  internal async void _set_im_fds  (Edsf.Persona persona,
      MultiMap<string, ImFieldDetails> im_fds) throws PropertyError
    {
      if (Utils.multi_map_str_afd_equal (persona.im_addresses, im_fds))
        return;

      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_im_fds (contact, im_fds);
          yield this._addressbook.modify_contact (contact, null);
        }
      catch (GLib.Error e)
        {
          throw this.e_client_error_to_property_error ("im-addresses", e);
        }
    }

  /* TODO: this could be smarter & more efficient. */
  private async void _set_contact_im_fds (E.Contact contact,
      MultiMap<string, ImFieldDetails> im_fds)
    {
      var im_eds_map = Edsf.Persona._get_im_eds_map ();

      /* First let's remove everything */
      foreach (var field_id in im_eds_map.get_values ())
        {
          /* Technically it's a (transfer full) list, but remove_attribute()
           * swallows ownership. */
          GLib.List<unowned VCardAttribute> attrs =
              contact.get_attributes (field_id);
          foreach (var attr in attrs)
            {
              contact.remove_attribute (attr);
            }
        }

     foreach (var proto in im_fds.get_keys ())
       {
         var attributes = new GLib.List <E.VCardAttribute>();
         var attrib_name = ("X-" + proto).up ();
         bool added = false;

         foreach (var im_fd in im_fds.get (proto))
           {
             var attr_n = new E.VCardAttribute (null, attrib_name);
             attr_n.add_value (im_fd.value);
             attributes.prepend ((owned) attr_n);
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
          yield this._addressbook.modify_contact (contact, null);
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

  internal async void _set_gender (Edsf.Persona persona,
      Gender gender) throws PropertyError
    {
      try
        {
          E.Contact contact = ((Edsf.Persona) persona).contact;
          yield this._set_contact_gender (contact, gender);
          yield this._addressbook.modify_contact (contact, null);
        }
      catch (GLib.Error e)
        {
          throw this.e_client_error_to_property_error ("gender", e);
        }
    }

  private async void _set_contact_gender (E.Contact contact,
      Gender gender)
    {
      unowned VCardAttribute attr =
          contact.get_attribute (Edsf.Persona.gender_attribute_name);
      if (attr != null)
        {
          contact.remove_attribute (attr);
        }

      var new_attr =
          new VCardAttribute (null, Edsf.Persona.gender_attribute_name);

      switch (gender)
        {
          case Gender.UNSPECIFIED:
            break;
          case Gender.MALE:
            new_attr.add_value (Edsf.Persona.gender_male);
            contact.add_attribute ((owned) new_attr);
            break;
          case Gender.FEMALE:
            new_attr.add_value (Edsf.Persona.gender_female);
            contact.add_attribute ((owned) new_attr);
            break;
        }
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

  /* Convert an EClientError or EBookClientError to a Folks.PropertyError for
   * property modifications. */
  private PropertyError e_client_error_to_property_error (string property_name,
      GLib.Error error_in)
    {
      if (error_in.domain == BookClient.error_quark ())
        {
          switch ((BookClientError) error_in.code)
            {
              /* We don't expect to receive any of the error codes below: */
              case BookClientError.CONTACT_NOT_FOUND:
              case BookClientError.NO_SUCH_BOOK:
              case BookClientError.CONTACT_ID_ALREADY_EXISTS:
              case BookClientError.NO_SUCH_SOURCE:
              case BookClientError.NO_SPACE:
              default:
                /* Fall out */
                break;
            }
        }
      else if (error_in.domain == Client.error_quark ())
        {
          switch ((ClientError) error_in.code)
            {
              case ClientError.REPOSITORY_OFFLINE:
              case ClientError.PERMISSION_DENIED:
              case ClientError.NOT_SUPPORTED:
              case ClientError.AUTHENTICATION_REQUIRED:
                /* TODO: Support authentication. bgo#653339 */
                return new PropertyError.NOT_WRITEABLE (
                    /* Translators: the first parameter is a non-human-readable
                     * property name and the second parameter is an error
                     * message. */
                    _("Property ‘%s’ is not writeable: %s"), property_name,
                    error_in.message);
              /* We expect to receive these, but they don't need special
               * error codes: */
              case ClientError.INVALID_ARG:
                return new PropertyError.INVALID_VALUE (
                    /* Translators: the first parameter is a non-human-readable
                     * property name and the second parameter is an error
                     * message. */
                    _("Invalid value for property ‘%s’: %s"), property_name,
                    error_in.message);
              case ClientError.BUSY:
              case ClientError.DBUS_ERROR:
              case ClientError.OTHER_ERROR:
                /* Fall through. */
              /* We don't expect to receive any of the error codes below: */
              case ClientError.COULD_NOT_CANCEL:
              case ClientError.AUTHENTICATION_FAILED:
              case ClientError.TLS_NOT_AVAILABLE:
              case ClientError.OFFLINE_UNAVAILABLE:
              case ClientError.UNSUPPORTED_AUTHENTICATION_METHOD:
              case ClientError.SEARCH_SIZE_LIMIT_EXCEEDED:
              case ClientError.SEARCH_TIME_LIMIT_EXCEEDED:
              case ClientError.INVALID_QUERY:
              case ClientError.QUERY_REFUSED:
              default:
                /* Fall out */
                break;
            }
        }

      /* Fallback error. */
      return new PropertyError.UNKNOWN_ERROR (
          /* Translators: the first parameter is a non-human-readable
           * property name and the second parameter is an error message. */
          _("Unknown error setting property ‘%s’: %s"), property_name,
          error_in.message);
    }
}
