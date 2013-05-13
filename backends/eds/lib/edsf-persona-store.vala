/*
 * Copyright (C) 2011 Collabora Ltd.
 * Copyright (C) 2013 Philip Withnall
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

/* The following function is needed in order to use the async SourceRegistry
 * constructor. FIXME: https://bugzilla.gnome.org/show_bug.cgi?id=659886 */
[CCode (cname = "e_source_registry_new", cheader_filename = "libedataserver/libedataserver.h", finish_function = "e_source_registry_new_finish")]
internal extern static async E.SourceRegistry create_source_registry (GLib.Cancellable? cancellable = null) throws GLib.Error;

/**
 * A persona store representing a single EDS address book.
 *
 * The persona store will contain {@link Edsf.Persona}s for each contact in the
 * address book it represents.
 */
public class Edsf.PersonaStore : Folks.PersonaStore
{
  private HashMap<string, Persona> _personas;
  private Map<string, Persona> _personas_ro;
  private bool _is_prepared = false;
  private bool _prepare_pending = false;
  private bool _is_quiescent = false;
  private HashSet<Persona>? _pending_personas = null; /* null before prepare()*/
  private E.BookClient? _addressbook = null; /* null before prepare() */
  private E.BookClientView? _ebookview = null; /* null before prepare() */
  private E.SourceRegistry? _source_registry = null; /* null before prepare() */
  private string _query_str;

  /* The timeout after which we consider a property change to have failed if we
   * haven't received a property change notification for it. */
  private const uint _property_change_timeout = 30; /* seconds */

  /* Translators: This should be translated to the name of the “Starred in
   * Android” group in Google Contacts for your language. If Google have not
   * localised the group for your language, or Google Contacts isn't available
   * in your language, please *do not* translate this string (i.e. just copy
   * the msgid to the msgstr unchanged). */
  internal const string android_favourite_group_name = N_("Starred in Android");

  internal static const string anti_links_attribute_name = "X-FOLKS-ANTI-LINKS";

  /**
   * The type of persona store this is.
   *
   * See {@link Folks.PersonaStore.type_id}.
   *
   * @since 0.6.0
   */
  public override string type_id { get { return BACKEND_NAME; } }

  /**
   * Create a new address book with the given ID.
   *
   * A new Address Book will be created with the given ID and the EDS
   * SourceRegistry will notice the new Address Book source and will emit
   * source_added with the new {@link E.Source} object which {@link Eds.Backend}
   * will then create a new {@link Edsf.PersonaStore} from.
   *
   * @param id the name and id for the new address book
   * @throws GLib.Error if an error occurred while creating or committing to
   * the {@link E.SourceRegistry}
   *
   * @since 0.9.0
   */
  public static async void create_address_book (string id) throws GLib.Error
    {
      debug ("Creating addressbook %s", id);
      /* In order to create a new Address Book with the given id we follow
       * the guidelines explained here: 
       * https://live.gnome.org/Evolution/ESourceMigrationGuide#How_do_I_create_a_new_calendar_or_address_book.3F
       * for setting the backend name and parent UID to "local" and 
       * "local-stub" respectively.
       */
      E.Source new_source = new E.Source.with_uid (id, null);
      
      new_source.set_parent ("local-stub");
      new_source.set_display_name (id);
      
      E.SourceAddressBook ab_extension =
        (E.SourceAddressBook) new_source.get_extension ("Address Book");
      ab_extension.set_backend_name ("local");
  
      E.SourceRegistry registry = yield create_source_registry ();
      yield registry.commit_source (new_source, null);
    }

  /**
   * Remove a persona store's address book permamently.
   *
   * This is a utility function to remove an {@link Edsf.PersonaStore}'s address
   * book from the disk permanently.  This simply wraps the EDS API to do 
   * the same.
   *
   * @param store the PersonaStore to delete the address book for.
   * @throws GLib.Error if an error occurred in {@link E.Source.remove}
   *
   * @since 0.9.0
   */
  public static async void remove_address_book (Edsf.PersonaStore store) throws GLib.Error
    {
      yield store.source.remove (null);
    }
  
  private void _address_book_notify_read_only_cb (Object address_book,
      ParamSpec pspec)
    {
      this._update_trust_level ();
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

          return ((!) this._addressbook).readonly
              ? MaybeBool.FALSE : MaybeBool.TRUE;
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
      get
        {
          return ("groups" in this._always_writeable_properties)
              ? MaybeBool.TRUE : MaybeBool.FALSE;
        }
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

          return ((!) this._addressbook).readonly
              ? MaybeBool.FALSE : MaybeBool.TRUE;
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

  private string[] _always_writeable_properties = {};
  private static string[] _always_writeable_properties_empty = {}; /* oh Vala */

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public override string[] always_writeable_properties
    {
      get
        {
          if (this._addressbook == null ||
              ((!) this._addressbook).readonly == true)
            {
              return PersonaStore._always_writeable_properties_empty;
            }

          return this._always_writeable_properties;
        }
    }

  /*
   * Whether this PersonaStore has reached a quiescent state.
   *
   * See {@link Folks.PersonaStore.is_quiescent}.
   *
   * @since 0.6.2
   */
  public override bool is_quiescent
    {
      get { return this._is_quiescent; }
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
   * The EDS {@link E.Source} associated with this persona store.
   *
   * @since 0.6.6
   */
  public E.Source source
    {
      get; construct;
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
  [Deprecated (since = "0.7.2",
      replacement = "Edsf.PersonaStore.with_source_registry()")]
  public PersonaStore (E.Source s)
    {
      string eds_uid = s.get_uid ();
      string eds_name = s.get_display_name ();
      Object (id: eds_uid,
              display_name: eds_name,
              source: s);

      this._source_registry = null; /* created in prepare() */
    }

  /**
   * Create a new PersonaStore.
   *
   * Create a new persona store to store the {@link Persona}s for the contacts
   * in ``s``. Passing a re-used source registry to the constructor (compared to
   * the old {@link Edsf.PersonaStore} constructor) saves a lot of time and
   * D-Bus round trips.
   *
   * @param r the EDS source registry giving access to all EDS sources
   * @param s the EDS source being represented by the persona store
   *
   * @since 0.7.2
   */
  public PersonaStore.with_source_registry (E.SourceRegistry r, E.Source s)
    {
      string eds_uid = s.get_uid ();
      Object (id: eds_uid,
              display_name: eds_uid,
              source: s);

      this._source_registry = r;
    }

  construct
    {
      this._personas = new HashMap<string, Persona> ();
      this._personas_ro = this._personas.read_only_view;
      this._query_str = "(contains \"x-evolution-any-field\" \"\")";
      this.source.changed.connect (this._source_changed_cb);
    }

  ~PersonaStore ()
    {
      try
        {
          if (this._ebookview != null)
            {
              ((!) this._ebookview).objects_added.disconnect (
                  this._contacts_added_cb);
              ((!) this._ebookview).objects_removed.disconnect (
                  this._contacts_removed_cb);
              ((!) this._ebookview).objects_modified.disconnect (
                  this._contacts_changed_cb);
              ((!) this._ebookview).complete.disconnect (
                  this._contacts_complete_cb);
              ((!) this._ebookview).stop ();

              this._ebookview = null;
            }

          if (this._addressbook != null)
            {
              ((!) this._addressbook).notify["readonly"].disconnect (
                  this._address_book_notify_read_only_cb);

              this._addressbook = null;
            }

          if (this._source_registry != null)
            {
              ((!) this._source_registry).source_removed.disconnect (
                  this._source_registry_changed_cb);
              ((!) this._source_registry).source_disabled.disconnect (
                  this._source_registry_changed_cb);
              this._source_registry = null;
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
   * Accepted keys for ``details`` are:
   * - PersonaStore.detail_key (PersonaDetail.AVATAR)
   * - PersonaStore.detail_key (PersonaDetail.BIRTHDAY)
   * - PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.FULL_NAME)
   * - PersonaStore.detail_key (PersonaDetail.GENDER)
   * - PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.IS_FAVOURITE)
   * - PersonaStore.detail_key (PersonaDetail.NICKNAME)
   * - PersonaStore.detail_key (PersonaDetail.PHONE_NUMBERS)
   * - PersonaStore.detail_key (PersonaDetail.POSTAL_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.ROLES)
   * - PersonaStore.detail_key (PersonaDetail.STRUCTURED_NAME)
   * - PersonaStore.detail_key (PersonaDetail.LOCAL_IDS)
   * - PersonaStore.detail_key (PersonaDetail.LOCATION)
   * - PersonaStore.detail_key (PersonaDetail.WEB_SERVICE_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.NOTES)
   * - PersonaStore.detail_key (PersonaDetail.URLS)
   * - PersonaStore.detail_key (PersonaDetail.GROUPS)
   *
   * See {@link Folks.PersonaStore.add_persona_from_details}.
   *
   * @throws Folks.PersonaStoreError.STORE_OFFLINE if the store hasn’t been
   * prepared
   * @throws Folks.PersonaStoreError.CREATE_FAILED if creating the persona in
   * the EDS store failed
   *
   * @since 0.6.0
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      // We have to have called prepare() beforehand.
      if (!this._is_prepared)
        {
          throw new PersonaStoreError.STORE_OFFLINE (
              "Persona store has not yet been prepared.");
        }

      E.Contact contact = new E.Contact ();

      var iter = HashTableIter<string, Value?> (details);
      unowned string k;
      unowned Value? _v;
      bool is_fav = false; // Remember this for _set_contact_groups.
      Set<string> groups = new SmallSet<string> (); // For _set_is_favourite

      while (iter.next (out k, out _v) == true)
        {
          if (_v == null)
            {
              continue;
            }
          unowned Value v = (!) _v;

          if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.FULL_NAME))
            {
              string? full_name = v.get_string ();
              if (full_name != null && (!) full_name == "")
                {
                  full_name = null;
                }

              contact.set (E.Contact.field_id ("full_name"), full_name);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.NICKNAME))
            {
              string? nickname = v.get_string ();
              if (nickname != null && (!) nickname == "")
                {
                  nickname = null;
                }

              contact.set (E.Contact.field_id ("nickname"), nickname);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.EMAIL_ADDRESSES))
            {
              Set<EmailFieldDetails> email_addresses =
                (Set<EmailFieldDetails>) v.get_object ();
              this._set_contact_attributes_string (contact,
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
              this._set_contact_im_fds (contact, im_fds);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.PHONE_NUMBERS))
            {
              Set<PhoneFieldDetails> phone_numbers =
                (Set<PhoneFieldDetails>) v.get_object ();
              this._set_contact_attributes_string (contact,
                  phone_numbers, "TEL",
                  E.ContactField.TEL);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.POSTAL_ADDRESSES))
            {
              Set<PostalAddressFieldDetails> postal_fds =
                (Set<PostalAddressFieldDetails>) v.get_object ();
              this._set_contact_postal_addresses (contact, postal_fds);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.STRUCTURED_NAME))
            {
              StructuredName sname = (StructuredName) v.get_object ();
              this._set_contact_name (contact, sname);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.LOCAL_IDS))
            {
              Set<string> local_ids = (Set<string>) v.get_object ();
              this._set_contact_local_ids (contact, local_ids);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.LOCATION))
            {
              var location = (Location?) v.get_object ();
              this._set_contact_location (contact, location);
            }
          else if (k == Folks.PersonaStore.detail_key
              (PersonaDetail.WEB_SERVICE_ADDRESSES))
            {
              HashMultiMap<string, WebServiceFieldDetails>
                web_service_addresses =
                (HashMultiMap<string, WebServiceFieldDetails>) v.get_object ();
              this._set_contact_web_service_addresses (contact,
                  web_service_addresses);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.NOTES))
            {
              var notes = (Gee.Set<NoteFieldDetails>) v.get_object ();
              this._set_contact_notes (contact, notes);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.GENDER))
            {
              var gender = (Gender) v.get_enum ();
              this._set_contact_gender (contact, gender);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.URLS))
            {
              Set<UrlFieldDetails> urls = (Set<UrlFieldDetails>) v.get_object ();
              this._set_contact_urls (contact, urls);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.BIRTHDAY))
            {
              var birthday = (DateTime?) v.get_boxed ();
              this._set_contact_birthday (contact, birthday);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.ROLES))
            {
              Set<RoleFieldDetails> roles =
                (Set<RoleFieldDetails>) v.get_object ();
              this._set_contact_roles (contact, roles);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.GROUPS))
            {
              groups = (Set<string>) v.get_object ();
              this._set_contact_groups (contact, groups, is_fav);
            }
          else if (k == Folks.PersonaStore.detail_key (
                  PersonaDetail.IS_FAVOURITE))
            {
              is_fav = v.get_boolean ();
              this._set_contact_is_favourite (contact, is_fav);
              /* Ensure the contact is added to the “Starred in Android” group
               * if appropriate. */
              this._set_contact_groups (contact, groups, is_fav);
            }
        }

      Edsf.Persona? _persona = null;

      try
        {
          /* _addressbook is guaranteed to be non-null before we ensure that
           * prepare() has already been called. */
          string added_uid;
          var result = yield ((!) this._addressbook).add_contact (contact,
              null,
              out added_uid);

          if (result)
            {
              debug ("Created contact with uid: %s\n", added_uid);
              lock (this._personas)
                {
                  var iid = Edsf.Persona.build_iid (this.id, added_uid);
                  _persona = this._personas.get (iid);
                  if (_persona == null)
                    {
                      Edsf.Persona persona;

                      contact.set (E.Contact.field_id ("id"), added_uid);
                      persona = new Persona (this, contact);
                      this._personas.set (persona.iid, persona);
                      var added_personas = new SmallSet<Persona> ();
                      added_personas.add (persona);
                      this._emit_personas_changed (added_personas, null);

                      _persona = persona;
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

      return _persona;
    }

  /**
   * Remove a {@link Persona} from the PersonaStore.
   *
   * See {@link Folks.PersonaStore.remove_persona}.
   *
   * @param persona the persona that should be removed
   * @throws Folks.PersonaStoreError.STORE_OFFLINE if the store hasn’t been
   * prepared or has gone offline
   * @throws Folks.PersonaStoreError.PERMISSION_DENIED if the store denied
   * permission to delete the contact
   * @throws Folks.PersonaStoreError.READ_ONLY if the store is read only
   * @throws Folks.PersonaStoreError.REMOVE_FAILED if any other errors happened
   * in the store
   *
   * @since 0.6.0
   */
  public override async void remove_persona (Folks.Persona persona)
      throws Folks.PersonaStoreError
    {
      // We have to have called prepare() beforehand.
      if (!this._is_prepared)
        {
          throw new PersonaStoreError.STORE_OFFLINE (
              "Persona store has not yet been prepared.");
        }

      try
        {
          /* _addressbook is guaranteed to be non-null before we ensure that
           * prepare() has already been called. */
          yield ((!) this._addressbook).remove_contact (
              ((Edsf.Persona) persona).contact, null);
        }
      catch (GLib.Error e)
        {
          if (e is BookClientError)
            {
              if (e is BookClientError.CONTACT_NOT_FOUND)
                {
                  /* Not an error, since we've got nothing to do! */
                  return;
                }

              /* We don't expect to receive any of the error codes below: */
              if (e is BookClientError.NO_SUCH_BOOK ||
                  e is BookClientError.CONTACT_ID_ALREADY_EXISTS ||
                  e is BookClientError.NO_SUCH_SOURCE ||
                  e is BookClientError.NO_SPACE)
                {
                  /* Fall out */
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
   * @throws Folks.PersonaStoreError.STORE_OFFLINE if the EDS store is offline
   * @throws Folks.PersonaStoreError.PERMISSION_DENIED if permission was denied
   * to open the EDS store
   * @throws Folks.PersonaStoreError.INVALID_ARGUMENT if any other error
   * occurred in the EDS store
   *
   * @since 0.6.0
   */
  public override async void prepare () throws PersonaStoreError
    {
      Internal.profiling_start ("preparing Edsf.PersonaStore (ID: %s)",
          this.id);

      if (this._is_prepared == true || this._prepare_pending == true)
        {
          return;
        }

      try
        {
          this._prepare_pending = true;

          try
            {
              /* Listen for removal signals for the address book. There's no
               * need to check if we still exist in the list, as
               * addressbook.open() will fail if we don't. */
              if (this._source_registry == null)
                {
                  this._source_registry = yield create_source_registry ();
                }

              /* We know _source_registry != null because otherwise
               * create_source_registry() would've thrown an error. */
              ((!) this._source_registry).source_removed.connect (
                  this._source_registry_changed_cb);
              ((!) this._source_registry).source_disabled.connect (
                  this._source_registry_changed_cb);

              /* Connect to the address book. */
              this._addressbook = yield E.BookClient.connect (this.source, null);

              ((!) this._addressbook).notify["readonly"].connect (
                  this._address_book_notify_read_only_cb);

              yield this._open_address_book ();
              debug ("Successfully finished opening address book %p for " +
                  "persona store ‘%s’ (%p).", this._addressbook, this.id, this);

              Internal.profiling_point ("opened address book in " +
                  "Edsf.PersonaStore (ID: %s)", this.id);

              this._notify_if_default ();
              this._update_trust_level ();
            }
          catch (GLib.Error e1)
            {
              /* Remove the persona store on error */
              this.removed ();

              if (e1 is BookClientError)
                {
                  /* We don't expect to receive any of the error codes
                   * below: */
                  if (e1 is BookClientError.NO_SUCH_BOOK ||
                      e1 is BookClientError.NO_SUCH_SOURCE ||
                      e1 is BookClientError.CONTACT_NOT_FOUND ||
                      e1 is BookClientError.CONTACT_ID_ALREADY_EXISTS ||
                      e1 is BookClientError.NO_SPACE)
                    {
                        /* Fall out */
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

          /* Determine which fields the address book supports. This is necessary
           * to work out which writeable properties we can support.
           *
           * Note: We assume this is constant over the lifetime of the address
           * book. This seems reasonable. */
          try
            {
              string? supported_fields = null;
              yield ((!) this._addressbook).get_backend_property (
                  "supported-fields", null, out supported_fields);

              Internal.profiling_point ("got supported fields in " +
                  "Edsf.PersonaStore (ID: %s)", this.id);

              var prop_set = new SmallSet<string> ();

              /* We get a comma-separated list of fields back. */
              if (supported_fields != null)
                {
                  string[] fields = ((!) supported_fields).split (",");

                  /* We always support local-ids, web-service-addresses, gender,
                   * anti-links and favourite because we use custom vCard
                   * attributes for them. */
                  prop_set.add ((!) Folks.PersonaStore.detail_key (
                      PersonaDetail.LOCAL_IDS));
                  prop_set.add ((!) Folks.PersonaStore.detail_key (
                      PersonaDetail.WEB_SERVICE_ADDRESSES));
                  prop_set.add ((!) Folks.PersonaStore.detail_key (
                      PersonaDetail.GENDER));
                  prop_set.add ((!) Folks.PersonaStore.detail_key (
                      PersonaDetail.IS_FAVOURITE));
                  prop_set.add ((!) Folks.PersonaStore.detail_key (
                      PersonaDetail.ANTI_LINKS));

                  foreach (unowned string field in fields)
                    {
                      var prop = Folks.PersonaStore.detail_key (
                          this._eds_field_name_to_folks_persona_detail (field));

                      if (prop != null)
                        {
                          prop_set.add ((!) (owned) prop);
                        }
                    }
                }

              /* Convert the property set to an array. We can't use .to_array()
               * here because it fails to null-terminate the array. Sigh. */
              this._always_writeable_properties = new string[prop_set.size];
              uint i = 0;
              foreach (var final_prop in prop_set)
                {
                  this._always_writeable_properties[i++] = final_prop;
                }
            }
          catch (GLib.Error e2)
            {
              /* Remove the persona store on error */
              this.removed ();

              throw new PersonaStoreError.INVALID_ARGUMENT (
                  /* Translators: the parameteter is an error message. */
                  _("Couldn't get address book capabilities: %s"), e2.message);
            }

          /* Get the set of capabilities supported by the address book.
           * Specifically, we're looking for do-initial-query, which signifies
           * that we should expect an initial _contacts_added_cb() callback. */
          var do_initial_query = false;
          try
            {
              string? capabilities = null;
              yield ((!) this._addressbook).get_backend_property (
                  "capabilities", null, out capabilities);

              Internal.profiling_point ("got capabilities in " +
                  "Edsf.PersonaStore (ID: %s)", this.id);

              if (capabilities != null)
                {
                  string[] caps = ((!) capabilities).split (",");

                  do_initial_query = ("do-initial-query" in caps);
                }
            }
          catch (GLib.Error e4)
            {
              /* Remove the persona store on error */
              this.removed ();

              throw new PersonaStoreError.INVALID_ARGUMENT (
                  /* Translators: the parameteter is an error message. */
                  _("Couldn't get address book capabilities: %s"), e4.message);
            }

          bool got_view = false;
          try
            {
              got_view = yield ((!) this._addressbook).get_view (
                  this._query_str, null, out this._ebookview);

              Internal.profiling_point ("opened book view in " +
                  "Edsf.PersonaStore (ID: %s)", this.id);

              if (got_view == false)
                {
                  throw new PersonaStoreError.INVALID_ARGUMENT (
                      /* Translators: the parameter is an address book URI. */
                      _("Couldn't get view for address book ‘%s’."),
                          this.id);
                }

              ((!) this._ebookview).objects_added.connect (
                  this._contacts_added_cb);
              ((!) this._ebookview).objects_removed.connect (
                  this._contacts_removed_cb);
              ((!) this._ebookview).objects_modified.connect (
                  this._contacts_changed_cb);
              ((!) this._ebookview).complete.connect (
                  this._contacts_complete_cb);

              ((!) this._ebookview).start ();
            }
          catch (GLib.Error e3)
            {
              /* Remove the persona store on error */
              this.removed ();

              if (e3 is BookClientError)
                {
                  /* We don't expect to receive any of the error codes
                   * below: */
                  if (e3 is BookClientError.NO_SUCH_BOOK ||
                      e3 is BookClientError.NO_SUCH_SOURCE ||
                      e3 is BookClientError.CONTACT_NOT_FOUND ||
                      e3 is BookClientError.CONTACT_ID_ALREADY_EXISTS ||
                      e3 is BookClientError.NO_SPACE)
                    {
                        /* Fall out */
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

          /* If the address book isn't going to do an initial query (i.e.
           * because it's a search-only address book, such as LDAP), we reach
           * a quiescent state immediately. */
          if (do_initial_query == false && this._is_quiescent == false)
            {
              assert (this._pending_personas == null); /* no initial query */
              this._is_quiescent = true;
              this.notify_property ("is-quiescent");
            }
        }
      finally
        {
          this._prepare_pending = false;
        }

      Internal.profiling_end ("preparing Edsf.PersonaStore");
    }

  /* Temporaries for _open_address_book(). See the complaint below. */
  Error? _open_address_book_error = null;
  SourceFunc? _open_address_book_callback = null; /* non-null iff yielded */

  /* Guarantees that either the address book will be open once the method
   * returns, or an error will be thrown.
   *
   * This method is not safe to run multiple times concurrently. */
  private async void _open_address_book () throws GLib.Error
    {
      Error? err_out = null;

      debug ("Opening address book %p for persona store ‘%s’ (%p)",
          this._addressbook, this.id, this);

      /* We have to connect to this weirdly because ‘opened’ is also a property
       * name. This means we can’t use a lambda function, which in turn means
       * that we need to build our own closure (or store some temporaries in
       * the persona store’s private data struct). Yuck. Yuck. Yuck. */
      var signal_id = Signal.connect_swapped ((!) this._addressbook, "opened",
        (Callback) this._address_book_opened_cb, this);

      try
        {
          this._open_address_book_error = null;

          yield ((!) this._addressbook).open (false, null);

          if (this._open_address_book_error != null)
            {
              throw this._open_address_book_error;
            }
        }
      catch (GLib.Error e1)
        {
          if (e1.domain == Client.error_quark () &&
              (ClientError) e1.code == ClientError.BUSY)
            {
              /* If we've received a BUSY error, it means that the address book
               * is already in the process of being opened by a different client
               * (most likely in a completely unrelated process). Since EDS is
               * kind enough not to block the open() call in this case, we have
               * to handle it ourselves by waiting for the ::opened signal,
               * which will be emitted once the address book is opened (or once
               * opening it fails).
               *
               * We yield until the ::opened callback is called, at which point
               * we return. The callback is a no-op if it’s called during the
               * open() call above. */
              this._open_address_book_callback =
                  this._open_address_book.callback;
              this._open_address_book_error = null;

              debug ("Yielding on opening address book %p for persona store " +
                  "‘%s’ (%p)", this._addressbook, this.id, this);
              yield;

              /* Propagate error/success. */
              err_out = this._open_address_book_error;
            }
          else
            {
              /* Error. */
              err_out = e1;
            }

          if (err_out != null)
            {
              throw err_out;
            }
        }
      finally
        {
          /* Disconnect the ::opened signal. */
          ((!) this._addressbook).disconnect (signal_id);

          /* We should really be able to expect that either the address book is
           * now open, or we have an error set. Unfortunately, this sometimes
           * isn't the case, probably due to misbehaving EDS backends (though
           * I haven't investigated). Just throw an error to be on the safe
           * side. */
          if (((!) this._addressbook).is_opened () == false && err_out == null)
            {
              err_out = new Error (Client.error_quark (),
                  ClientError.OTHER_ERROR, "Misbehaving EDS backend: %s.",
                  this.id);
            }
        }
    }

  private void _address_book_opened_cb (Error? err, BookClient address_book)
    {
      debug ("_address_book_opened_cb for store ‘%s’ (%p), address book %p " +
          "and error %p", this.id, this, address_book, (void*) err);

      this._open_address_book_error = err;

      if (this._open_address_book_callback != null)
        {
          this._open_address_book_callback ();
        }
    }

  private PersonaDetail _eds_field_name_to_folks_persona_detail (
      string eds_field_name)
    {
      var eds_field_id = Contact.field_id (eds_field_name);

      switch (eds_field_id)
        {
          case ContactField.FULL_NAME:
            return PersonaDetail.FULL_NAME;
          case ContactField.GIVEN_NAME:
          case ContactField.FAMILY_NAME:
          case ContactField.NAME:
            return PersonaDetail.STRUCTURED_NAME;
          case ContactField.GEO:
            return PersonaDetail.LOCATION;
          case ContactField.NICKNAME:
            return PersonaDetail.NICKNAME;
          case ContactField.EMAIL_1:
          case ContactField.EMAIL_2:
          case ContactField.EMAIL_3:
          case ContactField.EMAIL_4:
          case ContactField.EMAIL:
            return PersonaDetail.EMAIL_ADDRESSES;
          case ContactField.ADDRESS_LABEL_HOME:
          case ContactField.ADDRESS_LABEL_WORK:
          case ContactField.ADDRESS_LABEL_OTHER:
          case ContactField.ADDRESS:
          case ContactField.ADDRESS_HOME:
          case ContactField.ADDRESS_WORK:
          case ContactField.ADDRESS_OTHER:
            return PersonaDetail.POSTAL_ADDRESSES;
          case ContactField.PHONE_ASSISTANT:
          case ContactField.PHONE_BUSINESS:
          case ContactField.PHONE_BUSINESS_2:
          case ContactField.PHONE_BUSINESS_FAX:
          case ContactField.PHONE_CALLBACK:
          case ContactField.PHONE_CAR:
          case ContactField.PHONE_COMPANY:
          case ContactField.PHONE_HOME:
          case ContactField.PHONE_HOME_2:
          case ContactField.PHONE_HOME_FAX:
          case ContactField.PHONE_ISDN:
          case ContactField.PHONE_MOBILE:
          case ContactField.PHONE_OTHER:
          case ContactField.PHONE_OTHER_FAX:
          case ContactField.PHONE_PAGER:
          case ContactField.PHONE_PRIMARY:
          case ContactField.PHONE_RADIO:
          case ContactField.PHONE_TELEX:
          case ContactField.PHONE_TTYTDD:
          case ContactField.TEL:
          case ContactField.SIP:
            return PersonaDetail.PHONE_NUMBERS;
          case ContactField.ORG:
          case ContactField.ORG_UNIT:
          case ContactField.OFFICE:
          case ContactField.TITLE:
          case ContactField.ROLE:
          case ContactField.MANAGER:
          case ContactField.ASSISTANT:
            return PersonaDetail.ROLES;
          case ContactField.HOMEPAGE_URL:
          case ContactField.BLOG_URL:
          case ContactField.FREEBUSY_URL:
          case ContactField.VIDEO_URL:
            return PersonaDetail.URLS;
          case ContactField.CATEGORIES:
          case ContactField.CATEGORY_LIST:
            return PersonaDetail.GROUPS;
          case ContactField.NOTE:
            return PersonaDetail.NOTES;
          case ContactField.IM_AIM_HOME_1:
          case ContactField.IM_AIM_HOME_2:
          case ContactField.IM_AIM_HOME_3:
          case ContactField.IM_AIM_WORK_1:
          case ContactField.IM_AIM_WORK_2:
          case ContactField.IM_AIM_WORK_3:
          case ContactField.IM_GROUPWISE_HOME_1:
          case ContactField.IM_GROUPWISE_HOME_2:
          case ContactField.IM_GROUPWISE_HOME_3:
          case ContactField.IM_GROUPWISE_WORK_1:
          case ContactField.IM_GROUPWISE_WORK_2:
          case ContactField.IM_GROUPWISE_WORK_3:
          case ContactField.IM_JABBER_HOME_1:
          case ContactField.IM_JABBER_HOME_2:
          case ContactField.IM_JABBER_HOME_3:
          case ContactField.IM_JABBER_WORK_1:
          case ContactField.IM_JABBER_WORK_2:
          case ContactField.IM_JABBER_WORK_3:
          case ContactField.IM_YAHOO_HOME_1:
          case ContactField.IM_YAHOO_HOME_2:
          case ContactField.IM_YAHOO_HOME_3:
          case ContactField.IM_YAHOO_WORK_1:
          case ContactField.IM_YAHOO_WORK_2:
          case ContactField.IM_YAHOO_WORK_3:
          case ContactField.IM_MSN_HOME_1:
          case ContactField.IM_MSN_HOME_2:
          case ContactField.IM_MSN_HOME_3:
          case ContactField.IM_MSN_WORK_1:
          case ContactField.IM_MSN_WORK_2:
          case ContactField.IM_MSN_WORK_3:
          case ContactField.IM_ICQ_HOME_1:
          case ContactField.IM_ICQ_HOME_2:
          case ContactField.IM_ICQ_HOME_3:
          case ContactField.IM_ICQ_WORK_1:
          case ContactField.IM_ICQ_WORK_2:
          case ContactField.IM_ICQ_WORK_3:
          case ContactField.IM_AIM:
          case ContactField.IM_GROUPWISE:
          case ContactField.IM_JABBER:
          case ContactField.IM_YAHOO:
          case ContactField.IM_MSN:
          case ContactField.IM_ICQ:
          case ContactField.IM_GADUGADU_HOME_1:
          case ContactField.IM_GADUGADU_HOME_2:
          case ContactField.IM_GADUGADU_HOME_3:
          case ContactField.IM_GADUGADU_WORK_1:
          case ContactField.IM_GADUGADU_WORK_2:
          case ContactField.IM_GADUGADU_WORK_3:
          case ContactField.IM_GADUGADU:
          case ContactField.IM_SKYPE_HOME_1:
          case ContactField.IM_SKYPE_HOME_2:
          case ContactField.IM_SKYPE_HOME_3:
          case ContactField.IM_SKYPE_WORK_1:
          case ContactField.IM_SKYPE_WORK_2:
          case ContactField.IM_SKYPE_WORK_3:
          case ContactField.IM_SKYPE:
          case ContactField.IM_GOOGLE_TALK_HOME_1:
          case ContactField.IM_GOOGLE_TALK_HOME_2:
          case ContactField.IM_GOOGLE_TALK_HOME_3:
          case ContactField.IM_GOOGLE_TALK_WORK_1:
          case ContactField.IM_GOOGLE_TALK_WORK_2:
          case ContactField.IM_GOOGLE_TALK_WORK_3:
          case ContactField.IM_GOOGLE_TALK:
            return PersonaDetail.IM_ADDRESSES;
          case ContactField.PHOTO:
            return PersonaDetail.AVATAR;
          case ContactField.BIRTH_DATE:
            return PersonaDetail.BIRTHDAY;
          /* Irrelevant */
          case ContactField.UID: /* identifier */
          case ContactField.REV: /* revision date */
          case ContactField.BOOK_UID: /* parent identifier */
          case ContactField.NAME_OR_ORG: /* FULL_NAME or ORG; both handled */
            return PersonaDetail.INVALID;
          /* Unsupported */
          case ContactField.FILE_AS:
          case ContactField.MAILER:
          case ContactField.CALENDAR_URI:
          case ContactField.ICS_CALENDAR:
          case ContactField.SPOUSE:
          case ContactField.LOGO:
          case ContactField.WANTS_HTML:
          case ContactField.IS_LIST:
          case ContactField.LIST_SHOW_ADDRESSES:
          case ContactField.ANNIVERSARY:
          case ContactField.X509_CERT:
          default:
            debug ("Unsupported/Unknown EDS field name '%s'.", eds_field_name);
            return PersonaDetail.INVALID;
        }
    }

  /* Commit modified properties to the address book. This assumes you've already
   * modified the persona's contact appropriately. It guarantees to only return
   * once the modified property has been notified. */
  private async void _commit_modified_property (Edsf.Persona persona,
      string property_name) throws PropertyError
    {
      /* We require _addressbook to be non-null. This should be the case
       * because we're only called from property setters, and they check whether
       * the properties are writeable first. Properties shouldn't be writeable
       * if _addressbook is null. */
      assert (this._addressbook != null);

      var contact = persona.contact;

      ulong signal_id = 0;
      uint timeout_id = 0;

      try
        {
          var received_notification = false;
          var has_yielded = false;

          signal_id = persona.notify[property_name].connect ((obj, pspec) =>
            {
              /* Success! Return to _commit_modified_property(). */
              received_notification = true;

              if (has_yielded == true)
                {
                  this._commit_modified_property.callback ();
                }
            });

          /* Commit the modification. _addressbook is asserted as being non-null
           * above. */
          yield ((!) this._addressbook).modify_contact (contact, null);

          timeout_id = Timeout.add_seconds (PersonaStore._property_change_timeout, () =>
            {
              /* Failure! Return to _commit_modified_property() without setting
               * received_notification. */
              if (has_yielded == true)
                {
                  this._commit_modified_property.callback ();
                }

              return false;
            }, Priority.LOW);

          /* Wait until we get a notification that the property's changed. We
           * basically hold off on completing the GAsyncResult until the
           * signal handler for notification of the property change (above).
           * We only do this if we haven't already received a property change
           * notification. We don't need locking around these variables because
           * they can only be modified from the main loop. */
          if (received_notification == false)
            {
              has_yielded = true;
              yield;
            }

          /* If we hit the timeout instead of the property notification, throw
           * an error. */
          if (received_notification == false)
            {
              throw new PropertyError.UNKNOWN_ERROR (
                  /* Translators: the parameter is the name of a property on a
                   * contact, formatted in the normal GObject style (e.g.
                   * lowercase with hyphens to separate words). */
                  _("Changing the ‘%s’ property failed due to reaching the timeout."),
                  property_name);
            }
        }
      catch (GLib.Error e)
        {
          throw this.e_client_error_to_property_error (property_name, e);
        }
      finally
        {
          /* Remove the callbacks. */
          if (signal_id != 0)
            {
              persona.disconnect (signal_id);
            }

          if (timeout_id != 0)
            {
              GLib.Source.remove (timeout_id);
            }
        }
    }

  private void _remove_attribute (E.Contact contact, string attr_name)
    {
      unowned VCardAttribute? attr = contact.get_attribute (attr_name);
      if (attr != null)
        {
          contact.remove_attribute ((!) attr);
        }
    }

  internal async void _set_avatar (Edsf.Persona persona, LoadableIcon? avatar)
      throws PropertyError
    {
      if (!("avatar" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("Avatar is not writeable on this contact."));
        }

      /* Return early if there will be no change */
      if ((persona.avatar == null && avatar == null) ||
          (persona.avatar != null && ((!) persona.avatar).equal (avatar)))
        {
          return;
        }

      yield this._set_contact_avatar (persona.contact, avatar);
      yield this._commit_modified_property (persona, "avatar");
    }

  internal async void _set_web_service_addresses (Edsf.Persona persona,
      MultiMap<string, WebServiceFieldDetails> web_service_addresses)
          throws PropertyError
    {
      if (!("web-service-addresses" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("Web service addresses are not writeable on this contact."));
        }

      if (Utils.multi_map_str_afd_equal (persona.web_service_addresses,
            web_service_addresses))
        return;

      this._set_contact_web_service_addresses (persona.contact,
          web_service_addresses);
      yield this._commit_modified_property (persona, "web-service-addresses");
    }

  private void _set_contact_web_service_addresses (E.Contact contact,
      MultiMap<string, WebServiceFieldDetails> web_service_addresses)
    {
      this._remove_attribute (contact, "X-FOLKS-WEB-SERVICES-IDS");

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
      Set<UrlFieldDetails> urls) throws PropertyError
    {
      if (!("urls" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("URLs are not writeable on this contact."));
        }

      if (Utils.set_afd_equal (persona.urls, urls))
        return;

      this._set_contact_urls (persona.contact, urls);
      yield this._commit_modified_property (persona, "urls");
    }

  private void _set_contact_urls (E.Contact contact, Set<UrlFieldDetails> urls)
    {
      var vcard = (E.VCard) contact;
      vcard.remove_attributes (null, "X-URIS");
      contact.set (ContactField.HOMEPAGE_URL, null);
      contact.set (ContactField.VIDEO_URL, null);
      contact.set (ContactField.BLOG_URL, null);
      contact.set (ContactField.FREEBUSY_URL, null);

      foreach (var u in urls)
        {
          /* A way to escape from the inner loop, since Vala doesn't have
           * "continue 3". */
          var set_attr_already = false;

          var attr = new E.VCardAttribute (null, "X-URIS");
          attr.add_value (u.value);
          foreach (var param_name in u.parameters.get_keys ())
            {
              var param = new E.VCardAttributeParam (param_name.up ());
              foreach (var param_val in u.parameters.get (param_name))
                {
                  if (param_name == AbstractFieldDetails.PARAM_TYPE)
                    {
                      /* Handle TYPEs which need mapping to custom vCard attrs
                       * for EDS. */
                      foreach (var mapping in Edsf.Persona._url_properties)
                        {
                          if (param_val.down () == mapping.folks_type)
                            {
                              contact.set (
                                  E.Contact.field_id (mapping.vcard_field_name),
                                  u.value);

                              set_attr_already = true;
                              break;
                            }
                        }
                    }

                  if (set_attr_already == true)
                    {
                      break;
                    }

                  param.add_value (param_val);
                }

              if (set_attr_already == true)
                {
                  break;
                }

              attr.add_param (param);
            }

          if (set_attr_already == true)
            {
              continue;
            }

          contact.add_attribute ((owned) attr);
        }
    }

  internal async void _set_local_ids (Edsf.Persona persona,
      Set<string> local_ids) throws PropertyError
    {
      if (!("local-ids" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("Local IDs are not writeable on this contact."));
        }

      if (Folks.Internal.equal_sets<string> (local_ids, persona.local_ids))
        return;

      this._set_contact_local_ids (persona.contact, local_ids);
      yield this._commit_modified_property (persona, "local-ids");
    }

  private void _set_contact_local_ids (E.Contact contact, Set<string> local_ids)
    {
      this._remove_attribute (contact, "X-FOLKS-CONTACTS-IDS");

      var new_attr = new VCardAttribute (null, "X-FOLKS-CONTACTS-IDS");
      foreach (var local_id in local_ids)
        {
          new_attr.add_value (local_id);
        }

      contact.add_attribute ((owned) new_attr);
    }

  internal async void _set_is_favourite (Edsf.Persona persona,
      bool is_favourite) throws PropertyError
    {
      if (!("is-favourite" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("The contact cannot be marked as favourite."));
        }

      if (is_favourite == persona.is_favourite)
        return;

      this._set_contact_is_favourite (persona.contact, is_favourite);
      /* If this is a Google Contacts address book, change the user's membership
       * of the “Starred in Android” group accordingly. See: bgo#661490. */
      this._set_contact_groups (persona.contact, persona.groups, is_favourite);
      yield this._commit_modified_property (persona, "is-favourite");
    }

  private void _set_contact_is_favourite (E.Contact contact, bool is_favourite)
    {
      this._remove_attribute (contact, "X-FOLKS-FAVOURITE");

      if (is_favourite)
        {
          var new_attr = new VCardAttribute (null, "X-FOLKS-FAVOURITE");
          new_attr.add_value ("true");
          contact.add_attribute ((owned) new_attr);
        }
    }

  private async void _set_contact_avatar (E.Contact contact,
      LoadableIcon? avatar) throws PropertyError
    {
      if (avatar == null)
        {
          this._remove_attribute (contact, "PHOTO");
        }
      else
        {
          try
            {
              /* Set the avatar on the contact */
              var cp = new ContactPhoto ();
              cp.type = ContactPhotoType.INLINED;
              var input_s = yield ((!) avatar).load_async (-1, null, null);

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

              bool uncertain = false;
              var mime_type = ContentType.guess (null, image_data,
                  out uncertain);
              if (!uncertain)
                {
                  cp.set_mime_type (mime_type);
                }

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
      if (!("email-addresses" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("E-mail addresses are not writeable on this contact."));
        }

      if (Folks.Internal.equal_sets<EmailFieldDetails> (emails,
          persona.email_addresses))
        return;

      this._set_contact_attributes_string (persona.contact, emails,
          "EMAIL", E.ContactField.EMAIL);
      yield this._commit_modified_property (persona, "email-addresses");
    }

  internal async void _set_phones (Edsf.Persona persona,
      Set<PhoneFieldDetails> phones) throws PropertyError
    {
      if (!("phone-numbers" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("Phone numbers are not writeable on this contact."));
        }

      if (Folks.Internal.equal_sets<PhoneFieldDetails> (phones,
          persona.phone_numbers))
        return;

      this._set_contact_attributes_string (persona.contact, phones, "TEL",
          E.ContactField.TEL);
      yield this._commit_modified_property (persona, "phone-numbers");
    }

  internal async void _set_postal_addresses (Edsf.Persona persona,
      Set<PostalAddressFieldDetails> postal_fds) throws PropertyError
    {
      if (!("postal-addresses" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("Postal addresses are not writeable on this contact."));
        }

      if (Folks.Internal.equal_sets<PostalAddressFieldDetails> (postal_fds,
          persona.postal_addresses))
        return;

      this._set_contact_postal_addresses (persona.contact, postal_fds);
      yield this._commit_modified_property (persona, "postal-addresses");
    }

  private void _set_contact_postal_addresses (E.Contact contact,
      Set<PostalAddressFieldDetails> postal_fds)
    {
      this._set_contact_attributes<PostalAddress> (contact,
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

  private void _set_contact_attributes<T> (E.Contact contact,
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

  private void _set_contact_attributes_string (E.Contact contact,
      Set<AbstractFieldDetails<string>> new_attributes,
      string attrib_name, E.ContactField field_id)
    {
      this._set_contact_attributes<string> (contact, new_attributes,
          (attr, value) => { attr.add_value (value); },
          attrib_name, field_id);
    }

  internal async void _set_full_name (Edsf.Persona persona,
      string full_name) throws PropertyError
    {
      if (!("full-name" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("Full name is not writeable on this contact."));
        }

      string? _full_name = full_name;
      if (full_name == "")
        {
          _full_name = null;
        }

      if (persona.full_name == _full_name)
        return;

      persona.contact.set (E.Contact.field_id ("full_name"), _full_name);
      yield this._commit_modified_property (persona, "full-name");
    }

  internal async void _set_nickname (Edsf.Persona persona, string nickname)
      throws PropertyError
    {
      if (!("nickname" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("Nickname is not writeable on this contact."));
        }

      string? _nickname = nickname;
      if (nickname == "")
        {
          _nickname = null;
        }

      if (persona.nickname == _nickname)
        return;

      persona.contact.set (E.Contact.field_id ("nickname"), _nickname);
      yield this._commit_modified_property (persona, "nickname");
    }

  internal async void _set_notes (Edsf.Persona persona,
      Set<NoteFieldDetails> notes) throws PropertyError
    {
      if (!("notes" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("Notes are not writeable on this contact."));
        }

      if (Folks.Internal.equal_sets<NoteFieldDetails> (notes, persona.notes))
        return;

      this._set_contact_notes (persona.contact, notes);
      yield this._commit_modified_property (persona, "notes");
    }

  private void _set_contact_notes (E.Contact contact,
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

  internal async void _set_birthday (Edsf.Persona persona,
      DateTime? bday) throws PropertyError
    {
      if (!("birthday" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("Birthday is not writeable on this contact."));
        }

      if (persona.birthday != null &&
          bday != null &&
          ((!) persona.birthday).equal ((!) bday))
        return;

      /* Maybe the current and new b-day are unset */
      if (persona.birthday == null &&
          bday == null)
        return;

      this._set_contact_birthday (persona.contact, bday);
      yield this._commit_modified_property (persona, "birthday");
    }

  private void _set_contact_birthday (E.Contact contact, DateTime? _bday)
    {
      E.ContactDate? _contact_bday = null;

      if (_bday != null)
        {
          var bday = (!) _bday;
          var bdaylocal = bday.to_local();
          E.ContactDate contact_bday;

          contact_bday = new E.ContactDate ();
          contact_bday.year = (uint) bdaylocal.get_year ();
          contact_bday.month = (uint) bdaylocal.get_month ();
          contact_bday.day = (uint) bdaylocal.get_day_of_month ();

          _contact_bday = contact_bday;
        }

      contact.set (E.Contact.field_id ("birth_date"), _contact_bday);
    }

  internal async void _set_roles (Edsf.Persona persona,
      Set<RoleFieldDetails> roles) throws PropertyError
    {
      if (!("roles" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("Roles are not writeable on this contact."));
        }

      if (Folks.Internal.equal_sets<RoleFieldDetails> (roles, persona.roles))
        return;

      this._set_contact_roles (persona.contact, roles);
      yield this._commit_modified_property (persona, "roles");
    }

  private void _set_contact_roles (E.Contact contact,
      Set<RoleFieldDetails> roles)
    {
      var vcard = (E.VCard) contact;
      vcard.remove_attributes (null, "X-ROLES");

      string? org = null;
      string? org_unit = null;
      string? office = null;
      string? title = null;
      string? role = null;
      string? manager = null;
      string? assistant = null;

      /* Because e-d-s supports only fields for one Role we save the
       * first in the Set to the fields available and the rest goes
       * to X-ROLES */
      int count = 0;
      foreach (var role_fd in roles)
        {
          if (count == 0)
            {
              org = role_fd.value.organisation_name;
              title = role_fd.value.title;
              role = role_fd.value.role;

              /* FIXME: we are swallowing the extra parameter values */
              var org_unit_values = role_fd.get_parameter_values ("org_unit");
              if (org_unit_values != null &&
                  ((!) org_unit_values).size > 0)
                org_unit = ((!) org_unit_values).to_array ()[0];

              var office_values = role_fd.get_parameter_values ("office");
              if (office_values != null &&
                  ((!) office_values).size > 0)
                office = ((!) office_values).to_array ()[0];

              var manager_values = role_fd.get_parameter_values ("manager");
              if (manager_values != null &&
                  ((!) manager_values).size > 0)
                manager = ((!) manager_values).to_array ()[0];

              var assistant_values = role_fd.get_parameter_values ("assistant");
              if (assistant_values != null &&
                  ((!) assistant_values).size > 0)
                assistant = ((!) assistant_values).to_array ()[0];
            }
          else
            {
              var attr = new E.VCardAttribute (null, "X-ROLES");
              attr.add_value (role_fd.value.role);

              var param1 = new E.VCardAttributeParam ("organisation_name");
              param1.add_value (role_fd.value.organisation_name);
              attr.add_param (param1);

              var param2 = new E.VCardAttributeParam ("title");
              param2.add_value (role_fd.value.title);
              attr.add_param (param2);

              foreach (var param_name in role_fd.parameters.get_keys ())
                {
                  var param3 = new E.VCardAttributeParam (param_name.up ());
                  foreach (var param_val in role_fd.parameters.get (param_name))
                    {
                      param3.add_value (param_val);
                    }
                  attr.add_param (param3);
                }

              contact.add_attribute ((owned) attr);
            }

          count++;
        }

      contact.set (E.Contact.field_id ("org"), org);
      contact.set (E.Contact.field_id ("org_unit"), org_unit);
      contact.set (E.Contact.field_id ("office"), office);
      contact.set (E.Contact.field_id ("title"), title);
      contact.set (E.Contact.field_id ("role"), role);
      contact.set (E.Contact.field_id ("manager"), manager);
      contact.set (E.Contact.field_id ("assistant"), assistant);
    }

  internal async void _set_structured_name (Edsf.Persona persona,
      StructuredName? sname) throws PropertyError
    {
      if (!("structured-name" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("Structured name is not writeable on this contact."));
        }

      if (persona.structured_name != null && sname != null &&
          ((!) persona.structured_name).equal ((!) sname))
        return;

      /* Maybe the current and new name are unset */
      if (persona.structured_name == null && sname == null)
        return;

      this._set_contact_name (persona.contact, sname);
      yield this._commit_modified_property (persona, "structured-name");
    }

  private void _set_contact_name (E.Contact contact, StructuredName? _sname)
    {
      E.ContactName contact_name = new E.ContactName ();

      if (_sname != null)
        {
          var sname = (!) _sname;

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
      if (!("im-addresses" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("IM addresses are not writeable on this contact."));
        }

      if (Utils.multi_map_str_afd_equal (persona.im_addresses, im_fds))
        return;

      this._set_contact_im_fds (persona.contact, im_fds);
      yield this._commit_modified_property (persona, "im-addresses");
    }

  /* TODO: this could be smarter & more efficient. */
  private void _set_contact_im_fds (E.Contact contact,
      MultiMap<string, ImFieldDetails> im_fds)
    {
      var im_eds_map = Edsf.Persona._get_im_eds_map ();

      /* First let's remove everything */
      foreach (var field_id in im_eds_map.get_values ())
        {
          contact.remove_attributes (null, E.Contact.vcard_attribute (field_id));
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
      Set<string> groups) throws PropertyError
    {
      if (!("groups" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("Groups are not writeable on this contact."));
        }

      if (Folks.Internal.equal_sets<string> (groups, persona.groups))
        return;

      this._set_contact_groups (persona.contact, groups, persona.is_favourite);
      yield this._commit_modified_property (persona, "groups");
    }

  internal async void _set_system_groups (Edsf.Persona persona,
      Set<string> system_groups) throws PropertyError
    {
      if (!this._is_google_contacts_address_book ())
        {
          throw new PropertyError.NOT_WRITEABLE (_("My Contacts is only available for Google Contacts"));
        }

      if (Folks.Internal.equal_sets<string> (system_groups,
          persona.system_groups))
        return;

      this._set_contact_system_groups (persona.contact, system_groups);
      yield this._commit_modified_property (persona, "system-groups");
    }

  private void _set_contact_groups (E.Contact contact, Set<string> groups,
      bool is_favourite)
    {
      var categories = new GLib.List<string> ();

      foreach (var group in groups)
        {
          if (group == "")
            {
              continue;
            }
          else if (this._is_google_contacts_address_book () &&
              group == Edsf.PersonaStore.android_favourite_group_name)
            {
              continue;
            }

          categories.prepend (group);
        }

      /* If this is a Google address book, we must transparently add/remove the
       * “Starred in Android” group to/from the group list, depending on our
       * favourite status. */
      if (is_favourite && this._is_google_contacts_address_book ())
        {
          categories.prepend (Edsf.PersonaStore.android_favourite_group_name);
        }

      contact.set (ContactField.CATEGORY_LIST, categories);
    }

  private void _set_contact_system_groups (E.Contact contact, Set<string> system_groups)
    {
      var vcard = (E.VCard) contact;
      unowned E.VCardAttribute? prev_attr =
          vcard.get_attribute ("X-GOOGLE-SYSTEM-GROUP-IDS");

      if (prev_attr != null)
        contact.remove_attribute (prev_attr);

      E.VCardAttribute new_attr = new E.VCardAttribute ("", "X-GOOGLE-SYSTEM-GROUP-IDS");
      foreach (var group in system_groups)
        {
          if (group == null || group == "")
            {
              continue;
            }

          new_attr.add_value (group);
        }

      vcard.add_attribute (new_attr);
    }

  internal async void _set_gender (Edsf.Persona persona,
      Gender gender) throws PropertyError
    {
      if (!("gender" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("Gender is not writeable on this contact."));
        }

      if (gender == persona.gender)
        return;

      this._set_contact_gender (persona.contact, gender);
      yield this._commit_modified_property (persona, "gender");
    }

  private void _set_contact_gender (E.Contact contact, Gender gender)
    {
      this._remove_attribute (contact, Edsf.Persona.gender_attribute_name);

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

  internal async void _set_anti_links (Edsf.Persona persona,
      Set<string> anti_links) throws PropertyError
    {
      if (!("anti-links" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("Anti-links are not writeable on this contact."));
        }

      if (Folks.Internal.equal_sets<string> (anti_links, persona.anti_links))
        {
          return;
        }

      this._set_contact_anti_links (persona.contact, anti_links);
      yield this._commit_modified_property (persona, "anti-links");
    }

  private void _set_contact_anti_links (E.Contact contact,
      Set<string> anti_links)
    {
      var vcard = (E.VCard) contact;
      vcard.remove_attributes (null, PersonaStore.anti_links_attribute_name);

      var persona_uid =
          Folks.Persona.build_uid (BACKEND_NAME, this.id, contact.id);

      foreach (var anti_link_uid in anti_links)
        {
          /* Skip the persona's UID; don't allow reflexive anti-links. */
          if (anti_link_uid == persona_uid)
            {
              continue;
            }

          var attr = new E.VCardAttribute (null,
              PersonaStore.anti_links_attribute_name);
          attr.add_value (anti_link_uid);

          contact.add_attribute ((owned) attr);
        }
    }

  internal async void _set_location (Edsf.Persona persona,
      Location? location) throws PropertyError
    {
      if (!("location" in this._always_writeable_properties))
        {
          throw new PropertyError.NOT_WRITEABLE (
              _("Location is not writeable on this contact."));
        }

      this._set_contact_location (persona.contact, location);
      yield this._commit_modified_property (persona, "location");
    }

  private void _set_contact_location (E.Contact contact, Location? location)
    {
      if (location == null)
        {
          this._remove_attribute (contact, "GEO");
        }
      else
        {
          E.ContactGeo geo = new E.ContactGeo ();
          geo.latitude = location.latitude;
          geo.longitude = location.longitude;
          contact.set (ContactField.GEO, geo);
        }
    }

  /*
   * The EDS store receives change notifications as quickly as it
   * can and then stores them for later processing in a glib idle
   * callback.
   *
   * This avoids problems where many incoming D-Bus change notifications
   * block processing of other incoming D-Bus messages. Delays of over a minute
   * have been observed in worst-case (but not entirely unrealistic) scenarios
   * (1000 contacts added one-by-one while folks is active). See
   * https://bugzilla.gnome.org/show_bug.cgi?id=694385 (folks issue) and
   * http://bugs.freedesktop.org/show_bug.cgi?id=60851 (SyncEvolution issue).
   *
   * Cannot store a GLib.SourceFunc directly
   * in a LinkedList ("Delegates with target are not supported as generic type arguments",
   * https://mail.gnome.org/archives/vala-list/2011-June/msg00002.html)
   * and thus have to wrap it in a class. When dealing with delegates, we must be
   * careful to transfer ownership, because they are not reference counted.
   */
  class IdleTask
    {
      public GLib.SourceFunc callback;
    }


  private Gee.Queue<IdleTask> _idle_tasks = new Gee.LinkedList<IdleTask> ();
  private uint _idle_handle = 0;

  /*
   * Deal with some chunk of work encapsulated in the delegate later.
   * As in any other SourceFunc, the callback may request to be called
   * again by returning true. In contrast to Idle.add, _idle_queue
   * ensures that only one task is processed per idle cycle.
   */
  private void _idle_queue (owned GLib.SourceFunc callback)
    {
      IdleTask task = new IdleTask ();
      task.callback = (owned) callback;
      this._idle_tasks.add (task);
      /*
       * Ensure that there is an active idle callback to process
       * the task, otherwise register it. We cannot just
       * queue each task separately, because then we might
       * end up with multiple tasks being done at once
       * when the process gets idle, instead of one
       * task at a time.
       */
      if (this._idle_handle == 0)
        {
          this._idle_handle = Idle.add (this._idle_process);
        }
    }

  private bool _idle_process ()
    {
      IdleTask? task = this._idle_tasks.peek ();
      if (task != null)
        {
          if (task.callback ())
            {
               /* Task is not done yet, run it again later. */
               return true;
            }
          this._idle_tasks.poll ();
        }

      /* Check for future work. */
      task = this._idle_tasks.peek ();
      if (task == null)
        {
           /*
            * Remember that we need to re-register idle
            * processing when _idle_queue is called again.
            */
           this._idle_handle = 0;
           /* Done, will remove idle handler. */
           return false;
        }
      else
        {
           /* Continue processing. */
           return true;
        }
    }

  private Gee.LinkedList<E.Contact> _copy_contacts (GLib.List<E.Contact> contacts)
    {
      var copy = new Gee.LinkedList<E.Contact> ();
      foreach (E.Contact c in contacts)
        {
          copy.add (c);
        }
      return copy;
    }

  private Gee.LinkedList<string> _copy_contacts_ids (GLib.List<string> contacts_ids)
    {
      var copy = new Gee.LinkedList<string> ();
      foreach (unowned string s in contacts_ids)
        {
          copy.add (s);
        }
      return copy;
    }

  private void _contacts_added_cb (GLib.List<E.Contact> contacts)
    {
      var copy = this._copy_contacts (contacts);
      this._idle_queue (() => { return this._contacts_added_idle (copy); });
    }

  private bool _contacts_added_idle (Gee.List<E.Contact> contacts)
    {
      HashSet<Persona> added_personas;

      /* If the persona store hasn't yet reached quiescence, queue up the
       * personas and emit a notification about them later; see
       * _contacts_complete_cb() for details. */
      if (this._is_quiescent == false)
        {
          /* Lazily create pending_personas. */
          if (this._pending_personas == null)
            {
              this._pending_personas = new HashSet<Persona> ();
            }

          added_personas = this._pending_personas;
        }
      else
        {
          added_personas = new HashSet<Persona> ();
        }

      foreach (E.Contact c in contacts)
        {
          var iid = Edsf.Persona.build_iid_from_contact (this.id, c);
          if (this._personas.has_key (iid) == false)
            {
              var persona = new Persona (this, c);
              this._personas.set (persona.iid, persona);
              added_personas.add (persona);
            }
        }

      if (added_personas.size > 0 && this._is_quiescent == true)
        {
          this._emit_personas_changed (added_personas, null);
        }

      /* Done. */
      return false;
    }

  private void _contacts_changed_cb (GLib.List<E.Contact> contacts)
    {
      var copy = this._copy_contacts (contacts);
      this._idle_queue (() => { return this._contacts_changed_idle (copy); });
    }

  private bool _contacts_changed_idle (Gee.List<E.Contact> contacts)
    {
      foreach (E.Contact c in contacts)
        {
          var iid = Edsf.Persona.build_iid_from_contact (this.id, c);
          Persona? persona = this._personas.get (iid);
          if (persona != null)
            {
              ((!) persona)._update (c);
            }
        }
      return false;
    }

  private void _contacts_removed_cb (GLib.List<string> contacts_ids)
    {
      var copy = this._copy_contacts_ids (contacts_ids);
      this._idle_queue (() => { return this._contacts_removed_idle (copy); });
    }

  private bool _contacts_removed_idle (Gee.List<string> contacts_ids)
    {
      var removed_personas = new HashSet<Persona> ();

      foreach (string contact_id in contacts_ids)
        {
          var iid = Edsf.Persona.build_iid (this.id, contact_id);
          Persona? persona = _personas.get (iid);
          if (persona != null)
            {
              removed_personas.add ((!) persona);
              this._personas.unset (((!) persona).iid);

              /* Handle the case where a contact is removed before the persona
               * store has reached quiescence. */
              if (this._pending_personas != null)
                {
                  this._pending_personas.remove ((!) persona);
                }
            }
        }

       if (removed_personas.size > 0)
         {
           this._emit_personas_changed (null, removed_personas);
         }
      return false;
    }

  private void _contacts_complete_cb (Error err)
    {
      /* Handle errors. We treat an error in the first _contacts_complete_cb()
       * callback as unrecoverable, since it's being reported from the address
       * book's view creation code. Subsequent errors may be recoverable, since
       * they might be transient errors in refreshing the contact list. */
      if (err != null)
        {
          warning ("Error in address book view query: %s", err.message);
        }

      Internal.profiling_point ("initial query complete in " +
          "Edsf.PersonaStore (ID: %s)", this.id);

      /* Do the rest in an idle, so we don't signal that we are quiescent
       * before we actually have everyone. */
      this._idle_queue (() => { return this._contacts_complete_idle_cb (err); });
    }

  private bool _contacts_complete_idle_cb (Error err)
    {
      /* The initial query is complete, so signal that we've reached
       * quiescence (even if there was an error). */
      if (this._is_quiescent == false)
        {
          /* Handle initial errors. */
          if (err != null)
            {
              warning ("Error is considered unrecoverable. " +
                  "Removing persona store.");
              this.removed ();
              return false;
            }

          /* Emit a notification about all the personas which were found in the
           * initial query. They're queued up in _contacts_added_cb() and only
           * emitted here as _contacts_added_cb() may be called many times
           * before _contacts_complete_cb() is called. For example, EDS seems to
           * like emitting contacts in batches of 16 at the moment.
           * Queueing the personas up and emitting a single notification is a
           * lot more efficient for the individual aggregator to handle. */
          if (this._pending_personas != null)
            {
              this._emit_personas_changed (this._pending_personas, null);
              this._pending_personas = null;
            }

          this._is_quiescent = true;
          this.notify_property ("is-quiescent");
        }

      return false;
    }

  /* Convert an EClientError or EBookClientError to a Folks.PropertyError for
   * property modifications. */
  private PropertyError e_client_error_to_property_error (string property_name,
      GLib.Error error_in)
    {
      if (error_in is BookClientError)
        {
          /* We don't expect to receive any of the error codes below: */
          if (error_in is BookClientError.CONTACT_NOT_FOUND ||
              error_in is BookClientError.NO_SUCH_BOOK ||
              error_in is BookClientError.CONTACT_ID_ALREADY_EXISTS ||
              error_in is BookClientError.NO_SUCH_SOURCE ||
              error_in is BookClientError.NO_SPACE)
            {
                /* Fall out */
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

  private bool _backend_name_matches (string backend_name)
    {
      if (this.source.has_extension (SOURCE_EXTENSION_ADDRESS_BOOK))
        {
          unowned E.SourceAddressBook extension = (E.SourceAddressBook)
            this.source.get_extension (SOURCE_EXTENSION_ADDRESS_BOOK);

          return (extension.get_backend_name () == backend_name);
        }

      return false;
    }

  /* Try and work out whether this address book is Google Contacts. If so, we
   * can enable things like setting favourite status based on Android groups. */
  internal bool _is_google_contacts_address_book ()
    {
      /* Should only ever be called from property getters/setters. */
      assert (this._source_registry != null);

      /* backend name should be ‘google’ for Google Contacts address books */
      return this._backend_name_matches ("google");
    }

  private bool _is_in_source_registry ()
    {
      /* Should only ever be called from a callback from the source list itself,
       * so we can assert that the source list is non-null. */
      assert (this._source_registry != null);

      E.Source? needle = ((!) this._source_registry).ref_source (this.id);
      if (needle != null && needle.has_extension (SOURCE_EXTENSION_ADDRESS_BOOK))
        {
          /* We've found ourself. */
          return true;
        }

      return false;
    }

  /* Detect removal of the address book. We can't do this in Eds.Backend because
   * it has no way to tell the PersonaStore that it's been removed without
   * uglifying the store's public API. */
  private void _source_registry_changed_cb (E.Source list)
    {
      /* If we can't find our source, this persona store's address book has
       * been removed. */
      if (this._is_in_source_registry () == false)
        {
          /* Marshal the personas from a Collection to a Set. */
          var removed_personas = new HashSet<Persona> ();
          var iter = this._personas.map_iterator ();

          while (iter.next () == true)
            {
              removed_personas.add (iter.get_value ());
            }

          this._emit_personas_changed (null, removed_personas);
          this.removed ();
        }
    }

  /* This isn't perfect, since we want to base our trust of the address book on
   * whether *other people* can write to it (and potentially maliciously affect
   * the linking our aggregator does). However, since we can't know that, we
   * assume that if we can write to the address book we're probably in full
   * control of it. If we can't, either nobody/a sysadmin is (e.g. LDAP) or
   * or somebody else (who we can't trust) is (e.g. a read-only view of someone
   * else's WebDAV address book).
   */
  private void _update_trust_level ()
    {
      /* We may be called before prepare() has finished (and it may then fail),
       * but _addressbook should always be non-null when we're called. */
      assert (this._source_registry != null);
      assert (this._addressbook != null);

      /* backend_name should be ‘ldap’ for LDAP based address books */
      if (this._backend_name_matches ("ldap"))
        {
          this.trust_level = PersonaStoreTrust.PARTIAL;
          return;
        }

      if (this._is_google_contacts_address_book ())
        this.trust_level = PersonaStoreTrust.FULL;

      if (((!) this._addressbook).readonly)
        this.trust_level = PersonaStoreTrust.PARTIAL;
      else
        this.trust_level = PersonaStoreTrust.FULL;
    }

  private void _source_changed_cb ()
    {
      this._notify_if_default ();
    }

  private void _notify_if_default ()
    {
      bool is_default = false;

      /* By peeking at the default source instead of checking the value of
       * the "default" property, we include EDS's fallback logic for the
       * "system" address book */
      if (this._source_registry != null)
        {
          var default_source = this._source_registry.ref_default_address_book ();
          if (default_source != null &&
              this.source.get_uid () == ((!) default_source).get_uid ())
            {
              is_default = true;
            }

          if (is_default != this.is_user_set_default)
            {
              this.is_user_set_default = is_default;
            }
        }
    }
}
