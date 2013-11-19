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
 *         Travis Reitter <travis.reitter@collabora.co.uk>
 *         Philip Withnall <philip.withnall@collabora.co.uk>
 *         Marco Barisione <marco.barisione@collabora.co.uk>
 *         Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 */

using Folks;
using Gee;
using GLib;
using Tracker;
using Tracker.Sparql;

extern const string BACKEND_NAME;

internal enum Trf.Fields
{
  TRACKER_ID,
  FULL_NAME,
  FAMILY_NAME,
  GIVEN_NAME,
  ADDITIONAL_NAMES,
  PREFIXES,
  SUFFIXES,
  NICKNAME,
  BIRTHDAY,
  AVATAR_URL,
  IM_ADDRESSES,
  PHONES,
  EMAILS,
  URLS,
  FAVOURITE,
  CONTACT_URN,
  ROLES,
  NOTE,
  GENDER,
  POSTAL_ADDRESS,
  LOCAL_IDS_PROPERTY
}

internal enum Trf.AfflInfoFields
{
  IM_TRACKER_ID,
  IM_PROTOCOL,
  IM_ACCOUNT_ID,
  AFFL_TRACKER_ID,
  AFFL_ROLE,
  AFFL_ORG,
  AFFL_TITLE,
  AFFL_POBOX,
  AFFL_DISTRICT,
  AFFL_COUNTY,
  AFFL_LOCALITY,
  AFFL_POSTALCODE,
  AFFL_STREET_ADDRESS,
  AFFL_ADDRESS_LOCATION,
  AFFL_EXTENDED_ADDRESS,
  AFFL_COUNTRY,
  AFFL_REGION,
  AFFL_EMAIL,
  AFFL_PHONE,
  AFFL_WEBSITE,
  AFFL_BLOG,
  AFFL_URL,
  IM_NICKNAME
}

internal enum Trf.PostalAddressFields
{
  TRACKER_ID,
  POBOX,
  DISTRICT,
  COUNTY,
  LOCALITY,
  POSTALCODE,
  STREET_ADDRESS,
  ADDRESS_LOCATION,
  EXTENDED_ADDRESS,
  COUNTRY,
  REGION
}

internal enum Trf.UrlsFields
{
  TRACKER_ID,
  BLOG,
  WEBSITE,
  URL
}

internal enum Trf.RoleFields
{
  TRACKER_ID,
  ROLE,
  DEPARTMENT,
  TITLE
}

internal enum Trf.IMFields
{
  TRACKER_ID,
  PROTO,
  ID,
  IM_NICKNAME
}

internal enum Trf.PhoneFields
{
  TRACKER_ID,
  PHONE
}

internal enum Trf.EmailFields
{
  TRACKER_ID,
  EMAIL
}

internal enum Trf.TagFields
{
  TRACKER_ID
}

private enum Trf.Attrib
{
  EMAILS,
  PHONES,
  URLS,
  IM_ADDRESSES,
  POSTAL_ADDRESSES
}

private const char _REMOVE_ALL_ATTRIBS = 0x01;
private const char _REMOVE_PHONES      = 0x02;
private const char _REMOVE_POSTALS     = 0x04;
private const char _REMOVE_IM_ADDRS    = 0x08;
private const char _REMOVE_EMAILS      = 0x10;

/**
 * A persona store.
 * It will create {@link Persona}s for each contacts on the main addressbook.
 */
public class Trf.PersonaStore : Folks.PersonaStore
{
  private const string _LOCAL_ID_PROPERTY_NAME = "folks-linking-ids";
  private const string _WSD_PROPERTY_NAME = "folks-linking-ws-addrs";
  private const string _OBJECT_NAME = "org.freedesktop.Tracker1";
  private const string _OBJECT_IFACE = "org.freedesktop.Tracker1.Resources";
  private const string _OBJECT_PATH = "/org/freedesktop/Tracker1/Resources";
  private HashMap<string, Persona> _personas;
  private Map<string, Persona> _personas_ro;
  private bool _is_prepared = false;
  private bool _prepare_pending = false;
  private bool _is_quiescent = false;
  private static const int _default_timeout = 100;
  private Resources _resources_object;
  private Tracker.Sparql.Connection _connection;
  private static Gee.TreeMap<string, string> _urn_prefix = null;
  private static Gee.TreeMap<string, int> _prefix_tracker_id = null;
  private static const string _INITIAL_QUERY =
    "SELECT " +
    "tracker:id(?_contact) " +
    "nco:fullname(?_contact) " +
    "nco:nameFamily(?_contact) " +
    "nco:nameGiven(?_contact) " +
    "nco:nameAdditional(?_contact) " +
    "nco:nameHonorificPrefix(?_contact) " +
    "nco:nameHonorificSuffix(?_contact) " +
    "nco:nickname(?_contact) " +
    "nco:birthDate(?_contact) " +
    "nie:url(nco:photo(?_contact)) " +

    /* keep synced with Trf.IMFields */
    "(SELECT " +
    "GROUP_CONCAT ( " +
    " fn:concat(tracker:id(?affl),'\t'," +
    " tracker:coalesce(nco:imProtocol(?a),''), " +
    "'\t', tracker:coalesce(nco:imID(?a),''), '\t'," +
    " tracker:coalesce(nco:imNickname(?a),'')), '\\n') " +
    "WHERE { ?_contact nco:hasAffiliation ?affl. " +
    " ?affl nco:hasIMAddress ?a } ) " +

    /* keep synced with Trf.PhoneFields */
    "(SELECT " +
    "GROUP_CONCAT " +
    " (fn:concat(tracker:id(?affl),'\t', " +
    " nco:phoneNumber(?aff_number)), " +
    "'\\n') " +
    "WHERE { ?_contact nco:hasAffiliation ?affl . " +
    " ?affl nco:hasPhoneNumber ?aff_number  } ) " +

    /* keep synced with Trf.EmailFields */
    "(SELECT " +
    "GROUP_CONCAT " +
    " (fn:concat(tracker:id(?affl), '\t', " +
    "  nco:emailAddress(?emailaddress)), " +
    "',') " +
    "WHERE { ?_contact nco:hasAffiliation ?affl . " +
    " ?affl nco:hasEmailAddress ?emailaddress }) " +

    /* keep synced with Trf.UrlsFields */
    " (SELECT " +
    "GROUP_CONCAT " +
    " (fn:concat(tracker:id(?affl), '\t'," +
    "  tracker:coalesce(nco:blogUrl(?affl),'')," +
    "  '\t'," +
    "  tracker:coalesce(nco:websiteUrl(?affl),'')" +
    "  , '\t'," +
    "  tracker:coalesce(nco:url(?affl),''))," +
    "  '\\n') " +
    "WHERE { ?_contact nco:hasAffiliation ?affl  } )" +

    /* keep synced with Trf.TagFields */
    "(SELECT " +
    "GROUP_CONCAT(tracker:id(?_tag), " +
    "',') " +
    "WHERE { ?_contact nao:hasTag " +
    "?_tag }) " +

    "?_contact " +

    /* keep synced with Trf.RoleFields */
    "(SELECT " +
    "GROUP_CONCAT " +
    " (fn:concat(tracker:id(?affl), '\t', " +
    "  tracker:coalesce(nco:role(?affl),''), '\t', " +
    "  tracker:coalesce(nco:department(?affl),''), '\t', " +
    "  tracker:coalesce(nco:title(?affl),'')), " +
    "'\\n') " +
    "WHERE { ?_contact nco:hasAffiliation " +
    "?affl }) " +

    "nco:note(?_contact) " +
    "tracker:id(nco:gender(?_contact)) " +

    /* keep synced with Trf.PostalAddressFields*/
    "(SELECT " +
    "GROUP_CONCAT " +
    " (fn:concat(tracker:id(?affl), '\t', " +
    "  tracker:coalesce(nco:pobox(?postal),'')" +
    "  , '\t', " +
    "  tracker:coalesce(nco:district(?postal),'')" +
    "  , '\t', " +
    "  tracker:coalesce(nco:county(?postal),'')" +
    "  , '\t', " +
    "  tracker:coalesce(nco:locality(?postal),'')" +
    "  , '\t', " +
    "  tracker:coalesce(nco:postalcode(?postal),'')" +
    "  , '\t', " +
    "  tracker:coalesce(nco:streetAddress(?postal)" +
    "  ,''), '\t', " +
    "  tracker:coalesce(nco:addressLocation(?postal)" +
    "  ,''), '\t', " +
    "  tracker:coalesce(nco:extendedAddress(?postal)" +
    "  ,''), '\t', " +
    "  tracker:coalesce(nco:country(?postal),'')" +
    "  , '\t', " +
    "  tracker:coalesce(nco:region(?postal),'')),  " +
    "'\\n') " +
    "WHERE { ?_contact nco:hasAffiliation " +
    "?affl . ?affl nco:hasPostalAddress ?postal }) " +

    /* Linking between Trf.Personas */
    "(SELECT " +
    "GROUP_CONCAT " +
    " (?prop_value,  " +
    "',') " +
    "WHERE { ?_contact nao:hasProperty ?prop . " +
    " ?prop nao:propertyName ?prop_name . " +
    " ?prop nao:propertyValue ?prop_value . " +
    " FILTER (?prop_name = 'folks-linking-ids') } ) " +

    "{ ?_contact a nco:PersonContact . %s } " +
    "ORDER BY tracker:id(?_contact) ";

  private const string[] _always_writeable_properties =
    {
      "alias",
      "phone-numbers",
      "email-addresses",
      "avatar",
      "structured-name",
      "full-name",
      "gender",
      "birthday",
      "roles",
      "notes",
      "urls",
      "im-addresses",
      "is-favourite",
      "local-ids",
      "web-service-addresses",
      null /* FIXME: https://bugzilla.gnome.org/show_bug.cgi?id=682698 */
    };

  /**
   * The type of persona store this is.
   *
   * See {@link Folks.PersonaStore.type_id}.
   */
  public override string type_id { get { return BACKEND_NAME; } }

  /**
   * Whether this PersonaStore can add {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_add_personas}.
   *
   * @since 0.5.0
   */
  public override MaybeBool can_add_personas
    {
      get { return MaybeBool.TRUE; }
    }

  /**
   * Whether this PersonaStore can set the alias of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_alias_personas}.
   *
   * @since 0.5.0
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
   * @since 0.5.0
   */
  public override MaybeBool can_group_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore can remove {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_remove_personas}.
   *
   * @since 0.5.0
   */
  public override MaybeBool can_remove_personas
    {
      get { return MaybeBool.TRUE; }
    }

  /**
   * Whether this PersonaStore has been prepared.
   *
   * See {@link Folks.PersonaStore.is_prepared}.
   *
   * @since 0.5.0
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public override string[] always_writeable_properties
    {
      get { return Trf.PersonaStore._always_writeable_properties; }
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
   */
  public override Map<string, Persona> personas
    {
      get { return this._personas_ro; }
    }

  /**
   * Create a new PersonaStore.
   *
   * Create a new persona store to store the {@link Persona}s for the contacts
   */
  public PersonaStore ()
    {
      Object (id: BACKEND_NAME,
              display_name: BACKEND_NAME);
    }

  construct
    {
      this._personas = new HashMap<string, Persona> ();
      this._personas_ro = this._personas.read_only_view;
      debug ("Initial query : \n%s\n", PersonaStore._INITIAL_QUERY);
      this.trust_level = PersonaStoreTrust.FULL;
    }

  /**
   * Add a new {@link Persona} to the PersonaStore.
   *
   * Accepted keys for ``details`` are:
   * - PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.NICKNAME)
   * - PersonaStore.detail_key (PersonaDetail.FULL_NAME)
   * - PersonaStore.detail_key (PersonaDetail.IS_FAVOURITE)
   * - PersonaStore.detail_key (PersonaDetail.STRUCTURED_NAME)
   * - PersonaStore.detail_key (PersonaDetail.AVATAR)
   * - PersonaStore.detail_key (PersonaDetail.BIRTHDAY)
   * - PersonaStore.detail_key (PersonaDetail.GENDER)
   * - PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.NOTES)
   * - PersonaStore.detail_key (PersonaDetail.PHONE_NUMBERS)
   * - PersonaStore.detail_key (PersonaDetail.POSTAL_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.ROLES)
   * - PersonaStore.detail_key (PersonaDetail.URL)
   * - PersonaStore.detail_key (PersonaDetail.WEB_SERVICE_ADDRESSES)
   *
   * See {@link Folks.PersonaStore.add_persona_from_details}.
   *
   * @throws Folks.PersonaStoreError.INVALID_ARGUMENT if an unrecognised detail
   * key was passed in ``details``
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      /* We have to set the avatar after pushing the new persona to Tracker,
       * as we need a UID so that we can cache the avatar. */
      LoadableIcon? avatar = null;

      var builder = new Tracker.Sparql.Builder.update ();
      builder.insert_open (null);
      builder.subject ("_:p");
      builder.predicate ("a");
      builder.object ("nco:PersonContact");

      foreach (var k in details.get_keys ())
        {
          Value? v = details.lookup (k);
          if (k == Folks.PersonaStore.detail_key (PersonaDetail.NICKNAME))
            {
              builder.subject ("_:p");
              builder.predicate (Trf.OntologyDefs.NCO_NICKNAME);
              builder.object_string (v.get_string ());
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.FULL_NAME))
            {
              builder.subject ("_:p");
              builder.predicate (Trf.OntologyDefs.NCO_FULLNAME);
              builder.object_string (v.get_string ());
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.STRUCTURED_NAME))
            {
              StructuredName sname = (StructuredName) v.get_object ();
              builder.subject ("_:p");
              builder.predicate (Trf.OntologyDefs.NCO_FAMILY);
              builder.object_string (sname.family_name);
              builder.predicate (Trf.OntologyDefs.NCO_GIVEN);
              builder.object_string (sname.given_name);
              builder.predicate (Trf.OntologyDefs.NCO_ADDITIONAL);
              builder.object_string (sname.additional_names);
              builder.predicate (Trf.OntologyDefs.NCO_SUFFIX);
              builder.object_string (sname.suffixes);
              builder.predicate (Trf.OntologyDefs.NCO_PREFIX);
              builder.object_string (sname.prefixes);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.IS_FAVOURITE))
            {
              if (v.get_boolean ())
                {
                  builder.subject ("_:p");
                  builder.predicate (Trf.OntologyDefs.NAO_TAG);
                  builder.object (Trf.OntologyDefs.NAO_FAVORITE);
                }
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.AVATAR))
            {
              /* Update the avatar which we'll set later (once we have the
               * persona's UID) */
              var new_avatar = (LoadableIcon) v.get_object ();
              if (new_avatar != null)
                {
                  avatar = new_avatar;
                }
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.BIRTHDAY))
            {
              var birthday = (DateTime) v.get_boxed ();
              builder.subject ("_:p");
              builder.predicate (Trf.OntologyDefs.NCO_BIRTHDAY);
              TimeVal tv;
              birthday.to_timeval (out tv);
              builder.object_string (tv.to_iso8601 ());
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.GENDER))
            {
              var gender = (Gender) v.get_enum ();
              if (gender != Gender.UNSPECIFIED)
                {
                  builder.subject ("_:p");
                  builder.predicate (Trf.OntologyDefs.NCO_GENDER);
                  if (gender == Gender.MALE)
                    builder.object (Trf.OntologyDefs.NCO_MALE);
                  else
                    builder.object (Trf.OntologyDefs.NCO_FEMALE);
                }
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.EMAIL_ADDRESSES))
            {
              Set<EmailFieldDetails> email_addresses =
                (Set<EmailFieldDetails>) v.get_object ();
              yield this._build_update_query_set (builder, email_addresses,
                  "_:p", Trf.Attrib.EMAILS);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.IM_ADDRESSES))
            {
              var im_addresses =
                  (MultiMap<string, ImFieldDetails>) v.get_object ();

              int im_cnt = 0;
              foreach (var proto in im_addresses.get_keys ())
                {
                  var addrs_a = im_addresses.get (proto);

                  foreach (var im_fd in addrs_a)
                    {
                      var im_affl = "_:im_affl%d".printf (im_cnt);
                      var im = "_:im%d".printf (im_cnt);

                      builder.subject (im);
                      builder.predicate ("a");
                      builder.object (Trf.OntologyDefs.NCO_IMADDRESS);
                      builder.predicate (Trf.OntologyDefs.NCO_IMID);
                      builder.object_string (im_fd.value);
                      builder.predicate (Trf.OntologyDefs.NCO_IMPROTOCOL);
                      builder.object_string (proto);

                      builder.subject (im_affl);
                      builder.predicate ("a");
                      builder.object (Trf.OntologyDefs.NCO_AFFILIATION);
                      builder.predicate (Trf.OntologyDefs.NCO_HAS_IMADDRESS);
                      builder.object (im);

                      builder.subject ("_:p");
                      builder.predicate (Trf.OntologyDefs.NCO_HAS_AFFILIATION);
                      builder.object (im_affl);

                      im_cnt++;
                    }
                }
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.NOTES))
            {
              var notes = (Gee.Set<NoteFieldDetails>) v.get_object ();
              foreach (var n in notes)
                {
                  builder.subject ("_:p");
                  builder.predicate (Trf.OntologyDefs.NCO_NOTE);
                  builder.object_string (n.value);
                }
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.PHONE_NUMBERS))
            {
              Set<PhoneFieldDetails> phone_numbers =
                (Set<PhoneFieldDetails>) v.get_object ();
              yield this._build_update_query_set (builder, phone_numbers,
                "_:p", Trf.Attrib.PHONES);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.ROLES))
            {
              var roles = (Gee.Set<RoleFieldDetails>) v.get_object ();

              int roles_cnt = 0;
              foreach (var role_fd in roles)
                {
                  var role_affl = "_:role_affl%d".printf (roles_cnt);

                  builder.subject (role_affl);
                  builder.predicate ("a");
                  builder.object (Trf.OntologyDefs.NCO_AFFILIATION);
                  builder.predicate (Trf.OntologyDefs.NCO_ROLE);
                  builder.object_string (role_fd.value.role);
                  builder.predicate (Trf.OntologyDefs.NCO_TITLE);
                  builder.object_string (role_fd.value.title);
                  builder.predicate (Trf.OntologyDefs.NCO_ORG);
                  builder.object_string (role_fd.value.organisation_name);

                  builder.subject ("_:p");
                  builder.predicate (Trf.OntologyDefs.NCO_HAS_AFFILIATION);
                  builder.object (role_affl);

                  roles_cnt++;
                }
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.POSTAL_ADDRESSES))
            {
              Set<PostalAddressFieldDetails> postal_addresses =
                (Set<PostalAddressFieldDetails>) v.get_object ();

              int postal_cnt = 0;
              foreach (var pafd in postal_addresses)
                {
                  var pa = pafd.value;
                  var postal_affl = "_:postal_affl%d".printf (postal_cnt);
                  var postal = "_:postal%d".printf (postal_cnt);
                  builder.subject (postal);
                  builder.predicate ("a");
                  builder.object (Trf.OntologyDefs.NCO_POSTAL_ADDRESS);
                  builder.predicate (Trf.OntologyDefs.NCO_POBOX);
                  builder.object_string (pa.po_box);
                  builder.predicate (Trf.OntologyDefs.NCO_LOCALITY);
                  builder.object_string (pa.locality);
                  builder.predicate (Trf.OntologyDefs.NCO_POSTALCODE);
                  builder.object_string (pa.postal_code);
                  builder.predicate (Trf.OntologyDefs.NCO_STREET_ADDRESS);
                  builder.object_string (pa.street);
                  builder.predicate (Trf.OntologyDefs.NCO_EXTENDED_ADDRESS);
                  builder.object_string (pa.extension);
                  builder.predicate (Trf.OntologyDefs.NCO_COUNTRY);
                  builder.object_string (pa.country);
                  builder.predicate (Trf.OntologyDefs.NCO_REGION);
                  builder.object_string (pa.region);

                  builder.subject (postal_affl);
                  builder.predicate ("a");
                  builder.object (Trf.OntologyDefs.NCO_AFFILIATION);
                  builder.predicate (Trf.OntologyDefs.NCO_HAS_POSTAL_ADDRESS);
                  builder.object (postal);

                  builder.subject ("_:p");
                  builder.predicate (Trf.OntologyDefs.NCO_HAS_AFFILIATION);
                  builder.object (postal_affl);

                  postal_cnt++;
                }
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.URLS))
            {
              Set<UrlFieldDetails> url_fds =
                (Set<UrlFieldDetails>) v.get_object ();

              int url_cnt = 0;
              foreach (var url_fd in url_fds)
                {
                  var url_affl = "_:url_affl%d".printf (url_cnt);

                  builder.subject (url_affl);
                  builder.predicate ("a");
                  builder.object (Trf.OntologyDefs.NCO_AFFILIATION);
                  builder.predicate (Trf.OntologyDefs.NCO_URL);
                  builder.object_string (url_fd.value);

                  builder.subject ("_:p");
                  builder.predicate (Trf.OntologyDefs.NCO_HAS_AFFILIATION);
                  builder.object (url_affl);

                  url_cnt++;
                }
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.LOCAL_IDS))
            {
              var local_ids = (Gee.Set<string>) v.get_object ();
              string ids = Trf.PersonaStore.serialize_local_ids (local_ids);

              builder.subject ("_:folks_ids");
              builder.predicate ("a");
              builder.object (Trf.OntologyDefs.NAO_PROPERTY);
              builder.predicate (Trf.OntologyDefs.NAO_PROPERTY_NAME);
              builder.object_string (Trf.PersonaStore._LOCAL_ID_PROPERTY_NAME);
              builder.predicate (Trf.OntologyDefs.NAO_PROPERTY_VALUE);
              builder.object_string (ids);

              builder.subject ("_:p");
              builder.predicate (Trf.OntologyDefs.NAO_HAS_PROPERTY);
              builder.object ("_:folks_ids");
            }
          else if (k ==
              Folks.PersonaStore.detail_key (
                  PersonaDetail.WEB_SERVICE_ADDRESSES))
            {
              var ws_obj =
                (MultiMap<string, WebServiceFieldDetails>) v.get_object ();

              var ws_addrs = Trf.PersonaStore.serialize_web_services (ws_obj);

              builder.subject ("_:folks_ws_ids");
              builder.predicate ("a");
              builder.object (Trf.OntologyDefs.NAO_PROPERTY);
              builder.predicate (Trf.OntologyDefs.NAO_PROPERTY_NAME);
              builder.object_string (Trf.PersonaStore._WSD_PROPERTY_NAME);
              builder.predicate (Trf.OntologyDefs.NAO_PROPERTY_VALUE);
              builder.object_string (ws_addrs);

              builder.subject ("_:p");
              builder.predicate (Trf.OntologyDefs.NAO_HAS_PROPERTY);
              builder.object ("_:folks_ws_ids");
            }
          else
            {
              throw new PersonaStoreError.INVALID_ARGUMENT (
                  /* Translators: the first parameter is the unknown key that
                   * was received with the details params, and the second
                   * identifies the persona store. */
                _("Unrecognized parameter '%s' passed to persona store '%s'."),
                k, this.id);
            }
        }
      builder.insert_close ();

      Trf.Persona ret = null;
      string? contact_urn = yield this._insert_persona (builder.result,
          "p");
      if (contact_urn != null)
        {
          string filter = " FILTER(?_contact = <%s>) ".printf (contact_urn);
          string query = PersonaStore._INITIAL_QUERY.printf (filter);
          var ret_personas = yield this._do_add_contacts (query);

          /* Return the first persona we find in the set */
          foreach (var p in ret_personas)
            {
              ret = p;
              break;
            }
        }
      else
        {
          debug ("Failed to inserting the new persona  into Tracker.");
        }

      // Set the avatar on the persona now that we know the persona's UID
      if (ret != null && avatar != null)
        {
          yield this._set_avatar (ret, avatar);
        }

      return ret;
    }

 /**
   * Returns "service1:addr1,addr2;service2:addr3,.."
   *
   * @since 0.5.1
   */
  public static string serialize_web_services (
      MultiMap<string, WebServiceFieldDetails> ws_obj)
    {
      var str = "";

      foreach (var service in ws_obj.get_keys ())
        {
          if (str != "")
            {
              str += ";";
            }

          str += service + ":";

          var ws_fds = ws_obj.get (service);
          bool first = true;
          foreach (var ws_fd in ws_fds)
            {
              if (first == false)
                {
                  str += ",";
                }

              str += ws_fd.value;
              first = false;
            }
        }

      return str;
    }

 /**
   * Transforms "service1:addr1,addr2;service2:addr3,.." to
   *   --->  HashMultiMap<string, string>
   *
   * @since 0.5.1
   */
  public static
    MultiMap<string, WebServiceFieldDetails> unserialize_web_services (
        string ws_addrs)
    {
      var ret = new HashMultiMap<string, WebServiceFieldDetails> (
          null, null, AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

      var services = ws_addrs.split (";");
      foreach (var service_line in services)
          {
            var service_t = service_line.split (":");
            var service_name = service_t[0];
            var addrs = service_t[1].split (",");

            foreach (var a in addrs)
              {
                ret.set (service_name, new WebServiceFieldDetails (a));
              }
          }

      return ret;
    }

 /**
   * Transform Set<string> to "id1,id2,.."
   *
   * @since 0.5.1
   */
  public static string serialize_local_ids (Set<string> local_ids)
    {
      var str = "";

      foreach (var id in local_ids)
        {
          if (str != "")
            {
              str += ",";
            }
          str += id;
        }

      return str;
    }

  /**
   * Transform from id1,id2,.. to HashSet<string>
   *
   * @since 0.5.1
   */
  public static Set<string> unserialize_local_ids (string local_ids)
    {
      /* The documentation explicitly says this is a HashSet, so we shouldn't
       * switch it to SmallSet. Add a parallel API and update callers if
       * this turns out to be a hot path. */
      var ids = new HashSet<string> ();

      if (local_ids != "")
        {
          string[] ids_a = local_ids.split (",");
          foreach (var id in ids_a)
            {
              ids.add (id);
            }
        }

      return ids;
    }

  /**
   * Remove a {@link Persona} from the PersonaStore.
   *
   * See {@link Folks.PersonaStore.remove_persona}. This method is not safe to
   * call multiple times concurrently on the same persona.
   *
   * @throws Folks.PersonaStoreError currently unused
   */
  public override async void remove_persona (Folks.Persona persona)
      throws Folks.PersonaStoreError
    {
      var urn = yield this._remove_attributes_from_persona (persona,
          _REMOVE_ALL_ATTRIBS);

      /* Finally: remove literal properties */
      var q = " DELETE { " +
        " %s ?p ?o " +
        "} " +
        "WHERE { " +
        " %s ?p ?o " +
        "} ";
      yield this._tracker_update (q.printf (urn, urn), "remove_persona");
    }

  /* This method is not safe to call multiple times concurrently, since one call
   * could be part-way through removing attributes of the URN while a subsequent
   * call is attempting to retrieve the URN. */
  private async string _remove_attributes_from_persona (Folks.Persona persona,
      char remove_flag)
    {
      var urn = yield this._urn_from_persona (persona);
      yield this._remove_attributes (urn, remove_flag);
      return urn;
    }

  /* This method is safe to call multiple times concurrently. */
  private async void _build_update_query_set (
      Tracker.Sparql.Builder builder,
      Set<AbstractFieldDetails<string>> properties,
      string contact_var,
      Trf.Attrib attrib)
    {
      string? affl_var = null;
      string? obj_var = null;
      unowned string? related_attrib = null;
      unowned string? related_prop = null;
      unowned string? related_connection = null;

      switch (attrib)
        {
          case Trf.Attrib.PHONES:
            related_attrib = Trf.OntologyDefs.NCO_PHONE;
            related_prop = Trf.OntologyDefs.NCO_PHONE_PROP;
            related_connection = Trf.OntologyDefs.NCO_HAS_PHONE;
            affl_var = "_:phone_affl%d";
            obj_var = "_:phone%d";
            break;
          case Trf.Attrib.EMAILS:
            related_attrib = Trf.OntologyDefs.NCO_EMAIL;
            related_prop = Trf.OntologyDefs.NCO_EMAIL_PROP;
            related_connection = Trf.OntologyDefs.NCO_HAS_EMAIL;
            affl_var = "_:email_affl%d";
            obj_var = "_:email%d";
            break;
        }

      int cnt = 0;
      foreach (var p in properties)
        {
          var affl = affl_var.printf (cnt);
          var obj = yield this._urn_from_property (
              related_attrib, related_prop, p.value);

          if (obj == "")
            {
              obj = obj_var.printf (cnt);
              builder.subject (obj);
              builder.predicate ("a");
              builder.object (related_attrib);
              builder.predicate (related_prop);
              builder.object_string (p.value);
            }

          builder.subject (affl);
          builder.predicate ("a");
          builder.object (Trf.OntologyDefs.NCO_AFFILIATION);
          builder.predicate (related_connection);
          builder.object (obj);

          builder.subject (contact_var);
          builder.predicate (Trf.OntologyDefs.NCO_HAS_AFFILIATION);
          builder.object (affl);

          cnt++;
        }
    }

  /*
   * Garbage collecting related resources:
   *  - for each related resource we (recursively)
   *    check to if the deleted nco:Person
   *    is the only one holding a link, if so we
   *    remove the resource.
   *
   * This method is not safe to call multiple times concurrently, since the
   * deletions will race.
   */
  private async void _remove_attributes (string urn, char remove_flag)
    {
      SmallSet<string> affiliations =
       yield this._affiliations_from_persona (urn);

     foreach (var affl in affiliations)
       {
         bool got_attrib = false;

         if ((remove_flag & _REMOVE_ALL_ATTRIBS) ==
             _REMOVE_ALL_ATTRIBS ||
             (remove_flag & _REMOVE_PHONES) == _REMOVE_PHONES)
           {
             SmallSet<string> phones =
               yield this._phones_from_affiliation (affl);

             foreach (var phone in phones)
               {
                 got_attrib = true;
                 yield this._delete_resource (phone);
               }
           }

         if ((remove_flag & _REMOVE_ALL_ATTRIBS) ==
             _REMOVE_ALL_ATTRIBS ||
             (remove_flag & _REMOVE_POSTALS) == _REMOVE_POSTALS)
           {
             SmallSet<string> postals =
               yield this._postals_from_affiliation (affl);
             foreach (var postal in postals)
               {
                 got_attrib = true;
                 yield this._delete_resource (postal);
               }
           }

         if ((remove_flag & _REMOVE_ALL_ATTRIBS) ==
             _REMOVE_ALL_ATTRIBS ||
             (remove_flag & _REMOVE_IM_ADDRS) == _REMOVE_IM_ADDRS)
           {
             SmallSet<string> im_addrs =
               yield this._imaddrs_from_affiliation (affl);
             foreach (var im_addr in im_addrs)
               {
                 got_attrib = true;
                 yield this._delete_resource (im_addr);
               }
           }

         if ((remove_flag & _REMOVE_ALL_ATTRIBS) ==
             _REMOVE_ALL_ATTRIBS ||
             (remove_flag & _REMOVE_EMAILS) == _REMOVE_EMAILS)
           {
             SmallSet<string> emails =
               yield this._emails_from_affiliation (affl);
               foreach (var email in emails)
                 {
                   got_attrib = true;
                   yield yield this._delete_resource (email);
                 }
           }

         if (got_attrib ||
             (remove_flag & _REMOVE_ALL_ATTRIBS) == _REMOVE_ALL_ATTRIBS)
           yield this._delete_resource (affl);
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
   * @throws Folks.PersonaStoreError.INVALID_ARGUMENT if connecting to D-Bus
   * failed
   */
  public override async void prepare () throws GLib.Error
    {
      Internal.profiling_start ("preparing Trf.PersonaStore (ID: %s)", this.id);

      if (this._is_prepared || this._prepare_pending)
        {
          return;
        }

      try
        {
          this._prepare_pending = true;

          try
            {
              this._connection =
                yield Tracker.Sparql.Connection.get_async ();

              Internal.profiling_point ("got connection in " +
                  "Trf.PersonaStore (ID: %s)", this.id);

              yield this._build_predicates_table ();

              Internal.profiling_point ("build predicates table in " +
                  "Trf.PersonaStore (ID: %s)", this.id);

              yield this._do_add_contacts (PersonaStore._INITIAL_QUERY.printf (""));

              Internal.profiling_point ("added contacts in " +
                  "Trf.PersonaStore (ID: %s)", this.id);

              /* Don't add a match rule for all signals from Tracker but
               * only for GraphUpdated with the specific class we need. We
               * don't want to be woken up for irrelevent updates on the
               * graph.
               */
              this._resources_object = yield GLib.Bus.get_proxy<Resources> (
                  BusType.SESSION,
                  PersonaStore._OBJECT_NAME,
                  PersonaStore._OBJECT_PATH,
                  DBusProxyFlags.DO_NOT_CONNECT_SIGNALS |
                    DBusProxyFlags.DO_NOT_LOAD_PROPERTIES);
              this._resources_object.g_connection.signal_subscribe
                  (PersonaStore._OBJECT_NAME, PersonaStore._OBJECT_IFACE,
                  "GraphUpdated", PersonaStore._OBJECT_PATH,
                  Trf.OntologyDefs.PERSON_CLASS, GLib.DBusSignalFlags.NONE,
                  this._graph_updated_cb);

              Internal.profiling_point ("got resources proxy in " +
                  "Trf.PersonaStore (ID: %s)", this.id);

              this._is_prepared = true;
              this.notify_property ("is-prepared");

              /* By this time (due to having done the INITIAL_QUERY above)
               * we have already reached a quiescent state. */
              this._is_quiescent = true;
              this.notify_property ("is-quiescent");
            }
          catch (GLib.IOError e1)
            {
              /* Ignore errors from the bus disappearing. */
              if (!(e1 is IOError.CLOSED))
                {
                  warning ("Could not connect to D-Bus service: %s",
                      e1.message);
                }

              this.removed ();
              throw new PersonaStoreError.INVALID_ARGUMENT (e1.message);
            }
          catch (Tracker.Sparql.Error e2)
            {
              warning ("Error fetching SPARQL connection handler: %s",
                       e2.message);
              this.removed ();
              throw new PersonaStoreError.INVALID_ARGUMENT (e2.message);
            }
          catch (GLib.DBusError e3)
            {
              warning ("Could not connect to D-Bus service: %s",
                       e3.message);
              this.removed ();
              throw new PersonaStoreError.INVALID_ARGUMENT (e3.message);
            }
        }
      finally
        {
          this._prepare_pending = false;
        }

      Internal.profiling_end ("preparing Trf.PersonaStore (ID: %s)", this.id);
    }

  public int get_favorite_id ()
    {
      return PersonaStore._prefix_tracker_id.get
          (Trf.OntologyDefs.NAO_FAVORITE);
    }

  public int get_gender_male_id ()
    {
      return PersonaStore._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_MALE);
    }

  public int get_gender_female_id ()
    {
      return PersonaStore._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_FEMALE);
    }

  /* This is safe to call multiple times concurrently. */
  private async void _build_predicates_table ()
    {
      if (PersonaStore._prefix_tracker_id != null)
        {
          return;
        }

      this._build_urn_prefix_table ();

      PersonaStore._prefix_tracker_id = new Gee.TreeMap<string, int> ();

      string query = "SELECT  ";
      foreach (var urn_t in PersonaStore._urn_prefix.keys)
        {
          query += " tracker:id(" + urn_t + ")";
        }
      query += " WHERE {} ";

      try
        {
          Sparql.Cursor cursor = yield this._connection.query_async (query);

          while (cursor.next ())
            {
              int i=0;
              foreach (var urn in PersonaStore._urn_prefix.keys)
                {
                  var tracker_id = (int) cursor.get_integer (i);
                  var prefix = PersonaStore._urn_prefix.get (urn).dup ();
                  PersonaStore._prefix_tracker_id.set (prefix, tracker_id);
                  i++;
                }
            }
        }
      catch (Tracker.Sparql.Error e1)
        {
          warning ("Couldn't build predicates table: %s %s", query, e1.message);
        }
      catch (GLib.Error e2)
        {
          warning ("Couldn't build predicates table: %s %s", query, e2.message);
        }
    }

  private void _build_urn_prefix_table ()
    {
      if (PersonaStore._urn_prefix != null)
        {
          return;
        }
      PersonaStore._urn_prefix = new Gee.TreeMap<string, string> ();
      PersonaStore._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#fullname>",
          Trf.OntologyDefs.NCO_FULLNAME);
      PersonaStore._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nameFamily>",
          Trf.OntologyDefs.NCO_FAMILY);
      PersonaStore._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nameGiven>",
          Trf.OntologyDefs.NCO_GIVEN);
      PersonaStore._urn_prefix.set (
          Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nameAdditional>",
          Trf.OntologyDefs.NCO_ADDITIONAL);
      PersonaStore._urn_prefix.set (
          Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nameHonorificSuffix>",
          Trf.OntologyDefs.NCO_SUFFIX);
      PersonaStore._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nameHonorificPrefix>",
         Trf.OntologyDefs.NCO_PREFIX);
      PersonaStore._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nickname>",
         Trf.OntologyDefs.NCO_NICKNAME);
      PersonaStore._urn_prefix.set (
         Trf.OntologyDefs.RDF_URL_PREFIX + "22-rdf-syntax-ns#type>",
         Trf.OntologyDefs.RDF_TYPE);
      PersonaStore._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#PersonContact>",
         Trf.OntologyDefs.NCO_PERSON);
      PersonaStore._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#websiteUrl>",
         Trf.OntologyDefs.NCO_WEBSITE);
      PersonaStore._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#blogUrl>",
         Trf.OntologyDefs.NCO_BLOG);
      PersonaStore._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#url>",
         Trf.OntologyDefs.NCO_URL);
      PersonaStore._urn_prefix.set (
         Trf.OntologyDefs.NAO_URL_PREFIX + "nao#predefined-tag-favorite>",
         Trf.OntologyDefs.NAO_FAVORITE);
      PersonaStore._urn_prefix.set (Trf.OntologyDefs.NAO_URL_PREFIX + "nao#hasTag>",
         Trf.OntologyDefs.NAO_TAG);
      PersonaStore._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#hasEmailAddress>",
         Trf.OntologyDefs.NCO_HAS_EMAIL);
      PersonaStore._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#hasPhoneNumber>",
         Trf.OntologyDefs.NCO_HAS_PHONE);
      PersonaStore._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#hasAffiliation>",
         Trf.OntologyDefs.NCO_HAS_AFFILIATION);
      PersonaStore._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#birthDate>",
         Trf.OntologyDefs.NCO_BIRTHDAY);
      PersonaStore._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#note>",
         Trf.OntologyDefs.NCO_NOTE);
      PersonaStore._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#gender>",
         Trf.OntologyDefs.NCO_GENDER);
      PersonaStore._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#gender-male>",
         Trf.OntologyDefs.NCO_MALE);
      PersonaStore._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#gender-female>",
         Trf.OntologyDefs.NCO_FEMALE);
      PersonaStore._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#photo>",
         Trf.OntologyDefs.NCO_PHOTO);
      PersonaStore._urn_prefix.set (
         Trf.OntologyDefs.NAO_URL_PREFIX + "nao#hasProperty>",
         Trf.OntologyDefs.NAO_PROPERTY);
    }

  private void _graph_updated_cb (DBusConnection connection,
      string sender_name, string object_path, string interface_name,
      string signal_name, Variant parameters)
    {
      string class_name = "";
      VariantIter iter_del = null;
      VariantIter iter_ins = null;

      parameters.get("(sa(iiii)a(iiii))", &class_name, &iter_del, &iter_ins);

      if (class_name != Trf.OntologyDefs.PERSON_CLASS)
        {
          return;
        }

      this._handle_events.begin ((owned) iter_del, (owned) iter_ins);
    }

  private async void _handle_events
      (owned VariantIter iter_del, owned VariantIter iter_ins)
    {
      yield this._handle_delete_events ((owned) iter_del);
      yield this._handle_insert_events ((owned) iter_ins);
    }

  private async void _handle_delete_events (owned VariantIter iter_del)
    {
      var removed_personas = new HashSet<Persona> ();
      var nco_person_id =
          PersonaStore._prefix_tracker_id.get (Trf.OntologyDefs.NCO_PERSON);
      var rdf_type_id = PersonaStore._prefix_tracker_id.get (Trf.OntologyDefs.RDF_TYPE);
      Event e = Event ();

      while (iter_del.next
          ("(iiii)", &e.graph_id, &e.subject_id, &e.pred_id, &e.object_id))
        {
          var p_id = Trf.Persona.build_iid (this.id, e.subject_id.to_string ());
          if (e.pred_id == rdf_type_id &&
              e.object_id == nco_person_id)
            {
              var removed_p = this._personas.get (p_id);
              if (removed_p != null)
                {
                  removed_personas.add (removed_p);
                  _personas.unset (removed_p.iid);
                }
            }
          else
            {
              var persona = this._personas.get (p_id);
              if (persona != null)
                {
                  yield this._do_update (persona, e, false);
                }
            }
        }

      if (removed_personas.size > 0)
        {
          this._emit_personas_changed (null, removed_personas);
        }
    }

  private async void _handle_insert_events (owned VariantIter iter_ins)
    {
      var added_personas = new HashSet<Persona> ();
      Event e = Event ();

      while (iter_ins.next
          ("(iiii)", &e.graph_id, &e.subject_id, &e.pred_id, &e.object_id))
        {
          var subject_tracker_id = e.subject_id.to_string ();
          var p_id = Trf.Persona.build_iid (this.id, subject_tracker_id);
          Trf.Persona persona;
          persona = this._personas.get (p_id);
          if (persona == null)
            {
              persona = new Trf.Persona (this, subject_tracker_id);
              this._personas.set (persona.iid, persona);
              added_personas.add (persona);
            }
          yield this._do_update (persona, e);
        }

      if (added_personas.size > 0)
        {
          this._emit_personas_changed (added_personas, null);
        }
    }

  private async HashSet<Persona> _do_add_contacts (string query)
    {
      var added_personas = new HashSet<Persona> ();

      try {
        Sparql.Cursor cursor = yield this._connection.query_async (query);

        while (cursor.next ())
          {
            int tracker_id =
                (int) cursor.get_integer (Trf.Fields.TRACKER_ID);
            var p_id =
                Trf.Persona.build_iid (this.id, tracker_id.to_string ());
            if (this._personas.get (p_id) == null)
              {
                var persona = new Trf.Persona (this,
                    tracker_id.to_string (), cursor);
                this._personas.set (persona.iid, persona);
                added_personas.add (persona);
              }
          }

        if (added_personas.size > 0)
          {
            this._emit_personas_changed (added_personas, null);
          }
      } catch (GLib.Error e) {
        warning ("Couldn't perform queries: %s %s", query, e.message);
      }

      return added_personas;
    }

  /* This method is not safe to call multiple times concurrently on the same
   * persona, since the queries and updates will race. */
  private async void _do_update (Persona p, Event e, bool adding = true)
    {
      if (e.pred_id ==
          PersonaStore._prefix_tracker_id.get (Trf.OntologyDefs.NCO_FULLNAME))
        {
          string fullname = "";
          if (adding)
            {
              fullname =
                yield this._get_property (e.subject_id,
                    Trf.OntologyDefs.NCO_FULLNAME);
            }
          p._update_full_name (fullname);
        }
      else if (e.pred_id ==
               PersonaStore._prefix_tracker_id.get (Trf.OntologyDefs.NCO_NICKNAME))
        {
          string nickname = "";
          if (adding)
            {
              nickname =
                yield this._get_property (
                    e.subject_id, Trf.OntologyDefs.NCO_NICKNAME);
            }
          p._update_nickname (nickname);
        }
      else if (e.pred_id ==
               PersonaStore._prefix_tracker_id.get (Trf.OntologyDefs.NCO_FAMILY))
        {
          string family_name = "";
          if (adding)
            {
              family_name = yield this._get_property (e.subject_id,
                  Trf.OntologyDefs.NCO_FAMILY);
            }
          p._update_family_name (family_name);
        }
      else if (e.pred_id ==
               PersonaStore._prefix_tracker_id.get (Trf.OntologyDefs.NCO_GIVEN))
        {
          string given_name = "";
          if (adding)
            {
              given_name = yield this._get_property (
                  e.subject_id, Trf.OntologyDefs.NCO_GIVEN);
            }
          p._update_given_name (given_name);
        }
      else if (e.pred_id ==
               PersonaStore._prefix_tracker_id.get (Trf.OntologyDefs.NCO_ADDITIONAL))
        {
          string additional_name = "";
          if (adding)
            {
              additional_name = yield this._get_property
                  (e.subject_id, Trf.OntologyDefs.NCO_ADDITIONAL);
            }
          p._update_additional_names (additional_name);
        }
      else if (e.pred_id == PersonaStore._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_SUFFIX))
        {
          string suffix_name = "";
          if (adding)
            {
              suffix_name = yield this._get_property
                  (e.subject_id, Trf.OntologyDefs.NCO_SUFFIX);
            }
          p._update_suffixes (suffix_name);
        }
      else if (e.pred_id == PersonaStore._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_PREFIX))
        {
          string prefix_name = "";
          if (adding)
            {
              prefix_name = yield this._get_property
                  (e.subject_id, Trf.OntologyDefs.NCO_PREFIX);
            }
          p._update_prefixes (prefix_name);
        }
      else if (e.pred_id == PersonaStore._prefix_tracker_id.get
          (Trf.OntologyDefs.NAO_TAG))
        {
          if (e.object_id == this.get_favorite_id ())
            {
              if (adding)
                {
                  p._set_favourite (true);
                }
              else
                {
                  p._set_favourite (false);
                }
            }
        }
      else if (e.pred_id == PersonaStore._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_HAS_EMAIL))
        {
          if (adding)
            {
              var email = yield this._get_property (
                  e.object_id,
                  Trf.OntologyDefs.NCO_EMAIL_PROP,
                  Trf.OntologyDefs.NCO_EMAIL);
              p._add_email (email, e.object_id.to_string ());
            }
          else
            {
              p._remove_email (e.object_id.to_string ());
            }
        }
      else if (e.pred_id == PersonaStore._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_HAS_PHONE))
        {
          if (adding)
            {
              var phone = yield this._get_property (
                  e.object_id, Trf.OntologyDefs.NCO_PHONE_PROP,
                  Trf.OntologyDefs.NCO_PHONE);
              p._add_phone (phone, e.object_id.to_string ());
            }
          else
            {
              p._remove_phone (e.object_id.to_string ());
            }
        }
      else if (e.pred_id == PersonaStore._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_HAS_AFFILIATION))
        {
          if (adding)
            {
              var affl_info =
                yield this._get_affl_info (e.subject_id.to_string (),
                  e.object_id.to_string ());

              debug ("affl_info : %s", affl_info.to_string ());

              if (affl_info.im_tracker_id != null)
                {
                  p._update_nickname (affl_info.im_nickname);
                  if (affl_info.im_proto != null)
                    p._add_im_address (affl_info.affl_tracker_id,
                        affl_info.im_proto, affl_info.im_account_id);
                }

              if (affl_info.affl_tracker_id != null)
                {
                  if (affl_info.title != null ||
                      affl_info.org != null)
                    {
                      p._add_role (affl_info.affl_tracker_id, affl_info.role,
                          affl_info.title, affl_info.org);
                    }
                }

              if (affl_info.postal_address_fd != null)
                p._add_postal_address (affl_info.postal_address_fd);

              if (affl_info.phone != null)
                p._add_phone (affl_info.phone, e.object_id.to_string ());

              if (affl_info.email != null)
                p._add_email (affl_info.email, e.object_id.to_string ());

              if (affl_info.website != null)
                p._add_url (affl_info.website,
                    affl_info.affl_tracker_id,
                    UrlFieldDetails.PARAM_TYPE_HOME_PAGE);

              if (affl_info.blog != null)
                p._add_url (affl_info.blog,
                    affl_info.affl_tracker_id, UrlFieldDetails.PARAM_TYPE_BLOG);

              if (affl_info.url != null)
                p._add_url (affl_info.url,
                    affl_info.affl_tracker_id, null);
            }
          else
            {
              p._remove_im_address (e.object_id.to_string ());
              p._remove_role (e.object_id.to_string ());
              p._remove_postal_address (e.object_id.to_string ());
              p._remove_phone (e.object_id.to_string ());
              p._remove_email (e.object_id.to_string ());
              p._remove_url (e.object_id.to_string ());
            }
        }
      else if (e.pred_id == PersonaStore._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_BIRTHDAY))
        {
          string bday = "";
          if (adding)
            {
              bday = yield this._get_property (
                  e.subject_id, Trf.OntologyDefs.NCO_BIRTHDAY);
            }
          p._set_birthday (bday);
        }
      else if (e.pred_id == PersonaStore._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_NOTE))
        {
          string note = "";
          if (adding)
            {
              note = yield this._get_property (
                  e.subject_id, Trf.OntologyDefs.NCO_NOTE);
            }
          p._set_note (note);
        }
      else if (e.pred_id == PersonaStore._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_GENDER))
        {
          if (adding)
            {
              p._set_gender (e.object_id);
            }
          else
            {
              p._set_gender (0);
            }
        }
      else if (e.pred_id == PersonaStore._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_PHOTO))
        {
          string avatar_url = "";
          if (adding)
            {
              avatar_url = yield this._get_property (e.object_id,
                  Trf.OntologyDefs.NIE_URL, Trf.OntologyDefs.NFO_IMAGE);
            }
          p._set_avatar_from_uri (avatar_url);
        }
      else if (e.pred_id == PersonaStore._prefix_tracker_id.get
          (Trf.OntologyDefs.NAO_PROPERTY))
        {
          /* WARNING:
           *  nao:Properties shouldn't be abused since we have to reset
           *  them all when there is a DELETE. Plus, the Tracker devs
           *  say nao:Property is by nature slow. */
          if (adding)
            {
              string[] prop_info =  yield this._get_nao_property_by_prop_id (
                  e.object_id);
              if (prop_info[0] == Trf.PersonaStore._LOCAL_ID_PROPERTY_NAME)
                {
                  p._set_local_ids (prop_info[1]);
                }
              else if (prop_info[0] == Trf.PersonaStore._WSD_PROPERTY_NAME)
                {
                  p._set_web_service_addrs (prop_info[1]);
                }
            }
          else
            {
              string local_ids = yield this._get_nao_property_by_person_id (
                  e.subject_id,
                  Trf.PersonaStore._LOCAL_ID_PROPERTY_NAME);
              string ws_addrs = yield this._get_nao_property_by_person_id (
                  e.subject_id,
                  Trf.PersonaStore._WSD_PROPERTY_NAME);

              p._set_local_ids (local_ids);
              p._set_web_service_addrs (ws_addrs);
            }
        }
    }

  /* This method is safe to call multiple times concurrently. */
  private async string _get_property
      (int subject_tracker_id, string property,
       string subject_type = Trf.OntologyDefs.NCO_PERSON)
    {
      const string query_template =
        "SELECT ?property WHERE" +
        " { ?p a %s ; " +
        "   %s ?property " +
        " . FILTER(tracker:id(?p) = %d ) }";

      string query = query_template.printf (subject_type,
          property, subject_tracker_id);
      return yield this._single_value_query (query);
    }

  /* This method is safe to call multiple times concurrently. */
  private async string _get_nao_property_by_person_id (int nco_person_id,
      string prop_name)
    {
      const string query_t = "SELECT " +
        " ?prop_value " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " ; " +
        Trf.OntologyDefs.NAO_HAS_PROPERTY + " ?prop . " +
        " ?prop " + Trf.OntologyDefs.NAO_PROPERTY_NAME + " ?prop_name . " +
        " ?prop " + Trf.OntologyDefs.NAO_PROPERTY_VALUE + " ?prop_value . " +
        " FILTER (tracker:id(?p) = %d && ?prop_name = '%s') } ";

      string query = query_t.printf(nco_person_id, prop_name);
      return yield this._single_value_query (query);
    }

  /* This method is safe to call multiple times concurrently. */
  private async string[] _get_nao_property_by_prop_id (int nao_prop_id)
    {
      const string query_t = "SELECT " +
        " fn:concat(?prop_name, '\t', ?prop_value)" +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " ; " +
        Trf.OntologyDefs.NAO_HAS_PROPERTY + " ?prop . " +
        " ?prop " + Trf.OntologyDefs.NAO_PROPERTY_NAME + " ?prop_name . " +
        " ?prop " + Trf.OntologyDefs.NAO_PROPERTY_VALUE + " ?prop_value . " +
        " FILTER (tracker:id(?prop) = %d) } ";

      string query = query_t.printf(nao_prop_id);
      var ret = yield this._single_value_query (query);
      return ret.split ("\t");
    }

  /*
   * This should be kept in sync with Trf.AfflInfoFields
   *
   * This method is safe to call multiple times concurrently.
   */
  private async Trf.AfflInfo _get_affl_info (
      string person_id, string affiliation_id)
    {
      Trf.AfflInfo affl_info = new Trf.AfflInfo ();
      const string query_template =
        "SELECT " +
        "tracker:id(?i) " +
        Trf.OntologyDefs.NCO_IMPROTOCOL  + "(?i) " +
        Trf.OntologyDefs.NCO_IMID + "(?i) " +
        "tracker:id(?a) " +
        Trf.OntologyDefs.NCO_ROLE + "(?a) " +
        Trf.OntologyDefs.NCO_ORG + "(?a) " +
        Trf.OntologyDefs.NCO_TITLE + "(?a) " +
        Trf.OntologyDefs.NCO_POBOX + "(?postal) " +
        Trf.OntologyDefs.NCO_DISTRICT + "(?postal) " +
        Trf.OntologyDefs.NCO_COUNTY + "(?postal) " +
        Trf.OntologyDefs.NCO_LOCALITY + "(?postal) " +
        Trf.OntologyDefs.NCO_POSTALCODE + "(?postal) " +
        Trf.OntologyDefs.NCO_STREET_ADDRESS + "(?postal) " +
        Trf.OntologyDefs.NCO_ADDRESS_LOCATION + "(?postal) " +
        Trf.OntologyDefs.NCO_EXTENDED_ADDRESS + "(?postal) " +
        Trf.OntologyDefs.NCO_COUNTRY + "(?postal) " +
        Trf.OntologyDefs.NCO_REGION + "(?postal) " +
        Trf.OntologyDefs.NCO_EMAIL_PROP + "(?e) " +
        Trf.OntologyDefs.NCO_PHONE_PROP + "(?number) " +
        Trf.OntologyDefs.NCO_WEBSITE + "(?a) " +
        Trf.OntologyDefs.NCO_BLOG + "(?a) " +
        Trf.OntologyDefs.NCO_URL + "(?a) " +
        Trf.OntologyDefs.NCO_IM_NICKNAME + "(?i) " +
        "WHERE { "+
        " ?p a " + Trf.OntologyDefs.NCO_PERSON  + " ; " +
        Trf.OntologyDefs.NCO_HAS_AFFILIATION + " ?a . " +
        " OPTIONAL { ?a " + Trf.OntologyDefs.NCO_HAS_IMADDRESS + " ?i } . " +
        " OPTIONAL { ?a " + Trf.OntologyDefs.NCO_HAS_POSTAL_ADDRESS +
        "               ?postal } . " +
        " OPTIONAL { ?a " + Trf.OntologyDefs.NCO_HAS_EMAIL + " ?e } . " +
        " OPTIONAL { ?a " + Trf.OntologyDefs.NCO_HAS_PHONE + " ?number }  " +
        " FILTER(tracker:id(?p) = %s" +
        " && tracker:id(?a) = %s" +
        " ) } ";

      string query = query_template.printf (person_id, affiliation_id);

      debug ("_get_affl_info: %s", query);

      try
        {
          Sparql.Cursor cursor = yield this._connection.query_async (query);
          while (yield cursor.next_async ())
            {
              affl_info.im_tracker_id = cursor.get_string
                  (Trf.AfflInfoFields.IM_TRACKER_ID).dup ();
              affl_info.im_proto = cursor.get_string
                  (Trf.AfflInfoFields.IM_PROTOCOL).dup ();
              affl_info.im_account_id = cursor.get_string
                  (Trf.AfflInfoFields.IM_ACCOUNT_ID).dup ();
              affl_info.im_nickname = cursor.get_string
                  (Trf.AfflInfoFields.IM_NICKNAME).dup ();

              affl_info.affl_tracker_id = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_TRACKER_ID).dup ();
              affl_info.role = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_ROLE).dup ();
              affl_info.org = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_ORG).dup ();
              affl_info.title = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_TITLE).dup ();

              var po_box = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_POBOX).dup ();
              var extension = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_EXTENDED_ADDRESS).dup ();
              var street = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_STREET_ADDRESS).dup ();
              var locality = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_LOCALITY).dup ();
              var region = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_REGION).dup ();
              var postal_code = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_POSTALCODE).dup ();
              var country = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_COUNTRY).dup ();

              var postal_address = new Folks.PostalAddress (
                  po_box, extension, street, locality, region, postal_code,
                  country, null, affl_info.affl_tracker_id);
              if (!postal_address.is_empty ())
                {
                  affl_info.postal_address_fd =
                      new Folks.PostalAddressFieldDetails (postal_address);
                }

              affl_info.email = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_EMAIL).dup ();
              affl_info.phone = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_PHONE).dup ();

              affl_info.website = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_WEBSITE).dup ();
              affl_info.blog = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_BLOG).dup ();
              affl_info.url = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_URL).dup ();
            }
        }
      catch (Tracker.Sparql.Error e1)
        {
          warning ("Couldn't fetch affiliation info: %s %s",
              query, e1.message);
        }
      catch (GLib.Error e2)
        {
          warning ("Couldn't fetch affiliation info: %s %s",
              query, e2.message);
        }

      return affl_info;
    }

  /* This method is safe to call multiple times concurrently. */
  private async string? _insert_persona (string query, string persona_var)
    throws PersonaStoreError
    {
      GLib.Variant variant;
      string contact_urn = null;

      if (!this.is_prepared)
        {
          throw new PersonaStoreError.CREATE_FAILED("Cannot insert persona before store is prepared");
        }
      
      try
        {
          debug ("_insert_persona: %s", query);
          debug ("_connection is %p", this._connection);
          variant = yield this._connection.update_blank_async (query);

          VariantIter iter1, iter2, iter3;
          string anon_var = null;
          iter1 = variant.iterator ();

          while (iter1.next ("aa{ss}", out iter2))
            {
              if (iter2 == null)
                continue;

              while (iter2.next ("a{ss}", out iter3))
                {
                  if (iter3 == null)
                    continue;

                  while (iter3.next ("{ss}", out anon_var, out contact_urn))
                    {
                      /* The dictionary mapping blank node names to
                       * IRIs doesn't have a fixed order so we need
                       * check for the anon var corresponding to
                       * nco:PersonContact.
                       */
                      if (anon_var == persona_var)
                        return contact_urn;
                    }
                }
            }
        }
      catch (GLib.Error e)
        {
          contact_urn = null;
          warning ("Couldn't insert nco:PersonContact: %s", e.message);
        }

      return null;
    }

  /* This method is safe to call multiple times concurrently. */
  private async string _single_value_query (string query)
    {
      SmallSet<string> rows = yield this._multi_value_query (query);
      foreach (var r in rows)
        {
          return r;
        }
      return "";
    }

  /* This method is safe to call multiple times concurrently. */
  private async SmallSet<string> _multi_value_query (string query)
    {
      SmallSet<string> ret = new SmallSet<string> ();

      debug ("[_multi_value_query] %s", query);

      try
        {
          Sparql.Cursor cursor = yield this._connection.query_async (query);
          while (cursor.next ())
            {
              var prop = cursor.get_string (0);
              if (prop != null)
                ret.add (prop);
            }
        }
      catch (Tracker.Sparql.Error e1)
        {
          warning ("Couldn't run query: %s %s", query, e1.message);
        }
      catch (GLib.Error e2)
        {
          warning ("Couldn't run query: %s %s", query, e2.message);
        }

      return ret;
    }

  /* This method is safe to call multiple times concurrently. */
  private async string _urn_from_tracker_id (string tracker_id)
    {
      const string query = "SELECT fn:concat('<', tracker:uri(%s), '>') " +
        "WHERE {}";
      return yield this._single_value_query (query.printf (tracker_id));
    }

  /* This method is safe to call multiple times concurrently. */
  internal async void _set_nickname (Trf.Persona persona, string nickname)
    {
      const string query_t = "DELETE { "+
        " ?p " + Trf.OntologyDefs.NCO_NICKNAME + " ?n  " +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " ; " +
        Trf.OntologyDefs.NCO_NICKNAME + " ?n . " +
        " FILTER(tracker:id(?p) = %s) " +
        "} " +
        "INSERT { " +
        " ?p " + Trf.OntologyDefs.NCO_NICKNAME + " '%s' " +
        "} " +
        "WHERE { "+
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " . " +
        "FILTER (tracker:id(?p) = %s) " +
        "} ";

      string query = query_t.printf (persona.tracker_id, nickname,
          persona.tracker_id);

      yield this._tracker_update (query, "change_nickname");
    }

  /* This method is safe to call multiple times concurrently. */
  internal async void _set_local_ids (Trf.Persona persona,
      Set<string> local_ids)
    {
      string ids = Trf.PersonaStore.serialize_local_ids (local_ids);
      yield this._set_tracker_property (persona,
          Trf.PersonaStore._LOCAL_ID_PROPERTY_NAME, ids,
          "_set_local_ids");
    }

  /* This method is safe to call multiple times concurrently. */
  internal async void _set_web_service_addrs (Trf.Persona persona,
      MultiMap<string, WebServiceFieldDetails> ws_obj)
    {
      var ws_addrs = Trf.PersonaStore.serialize_web_services (ws_obj);
      yield this._set_tracker_property (persona,
          Trf.PersonaStore._WSD_PROPERTY_NAME, ws_addrs,
          "_set_web_service_addrs");
    }

  /* This method is safe to call multiple times concurrently. */
  private async void _set_tracker_property(Trf.Persona persona,
      string prop_name, string prop_value, string callers_name)
    {
      const string query_t = "DELETE " +
      " { ?p " + Trf.OntologyDefs.NAO_HAS_PROPERTY + " ?prop } " +
      "WHERE { " +
      " ?p a " + Trf.OntologyDefs.NCO_PERSON + " ; " +
      Trf.OntologyDefs.NAO_HAS_PROPERTY + " ?prop . " +
      " ?prop " + Trf.OntologyDefs.NAO_PROPERTY_NAME + " ?prop_name . " +
      " FILTER (tracker:id(?p) = %s && ?name = '%s' ) } " +
      "INSERT { " +
      " _:prop a " + Trf.OntologyDefs.NAO_PROPERTY + " ; " +
      Trf.OntologyDefs.NAO_PROPERTY_NAME +
      " '%s' ; " +
      Trf.OntologyDefs.NAO_PROPERTY_VALUE + " '%s' . " +
      " ?p " + Trf.OntologyDefs.NAO_HAS_PROPERTY + " _:prop " +
      "} " +
      "WHERE { " +
      " ?p a nco:PersonContact . " +
      "FILTER (tracker:id(?p) = %s) } ";

      string query = query_t.printf (persona.tracker_id, prop_name,
          prop_name, prop_value, persona.tracker_id);
      yield this._tracker_update (query, callers_name);
    }

  /* This method is safe to call multiple times concurrently. */
  internal async void _set_is_favourite (Folks.Persona persona,
      bool is_favourite)
    {
      const string ins_q = "INSERT { " +
        " ?p " + Trf.OntologyDefs.NAO_TAG + " " +
        Trf.OntologyDefs.NAO_FAVORITE +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON +
        " FILTER (tracker:id(?p) = %s) " +
        "} ";
      const string del_q = "DELETE { " +
        " ?p " + Trf.OntologyDefs.NAO_TAG + " " +
        Trf.OntologyDefs.NAO_FAVORITE + " " +
       "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON +
        " FILTER (tracker:id(?p) = %s) " +
        "} ";
      string query;

      if (is_favourite)
        {
          query = ins_q.printf (((Trf.Persona) persona).tracker_id);
        }
      else
        {
          query = del_q.printf (((Trf.Persona) persona).tracker_id);
        }

      yield this._tracker_update (query, "change_is_favourite");
    }

  /* This method may not be safe to call multiple times concurrently. */
  internal async void _set_emails (Folks.Persona persona,
      Set<EmailFieldDetails> emails)
    {
      yield this._set_unique_attrib_set (persona, emails,
          Trf.Attrib.EMAILS);
    }

  /* This method may not be safe to call multiple times concurrently. */
  internal async void _set_phones (Folks.Persona persona,
      Set<PhoneFieldDetails> phone_numbers)
    {
      yield this._set_unique_attrib_set (persona, phone_numbers,
          Trf.Attrib.PHONES);
    }

  /* This method may not be safe to call multiple times concurrently. */
  internal async void _set_unique_attrib_set (Folks.Persona persona,
      Set<AbstractFieldDetails<string>> properties, Trf.Attrib attrib)
    {
      string? query_name = null;
      var p_id = ((Trf.Persona) persona).tracker_id;
      var builder = new Tracker.Sparql.Builder.update ();
      builder.insert_open (null);

      switch (attrib)
        {
          case Trf.Attrib.PHONES:
            query_name = "_set_phones";
            yield this._remove_attributes_from_persona (persona,
                _REMOVE_PHONES);
            yield this._build_update_query_set (builder, properties,
                "?contact", Trf.Attrib.PHONES);
            break;
          case Trf.Attrib.EMAILS:
            query_name = "_set_emailss";
            yield this._remove_attributes_from_persona (persona,
                _REMOVE_EMAILS);
            yield this._build_update_query_set (builder, properties,
                "?contact", Trf.Attrib.EMAILS);
            break;
        }
      builder.insert_close ();
      builder.where_open ();
      builder.subject ("?contact");
      builder.predicate ("a");
      builder.object (Trf.OntologyDefs.NCO_PERSON);
      string filter = " FILTER(tracker:id(?contact) = %s) ".printf (p_id);
      builder.append (filter);
      builder.where_close ();

      yield this._tracker_update (builder.result, query_name);
    }

  /* This method is probably not safe to call multiple times concurrently. */
  internal async void _set_urls (Folks.Persona persona,
      Set<UrlFieldDetails> urls)
    {
       yield this._set_attrib_set (persona, urls,
          Trf.Attrib.URLS);
    }

  /* This method is probably not safe to call multiple times concurrently. */
  internal async void _set_im_addresses (Folks.Persona persona,
      MultiMap<string, ImFieldDetails> im_addresses)
    {
      var ims = new SmallSet<ImFieldDetails> ();
      foreach (var proto in im_addresses.get_keys ())
        {
          var addrs = im_addresses.get (proto);
          foreach (var im_fd in addrs)
            {
              var new_im_fd = new ImFieldDetails (im_fd.value);
              new_im_fd.set_parameter ("proto", proto);
              ims.add (new_im_fd);
            }
        }

       yield this._set_attrib_set (persona, ims, Trf.Attrib.IM_ADDRESSES);
    }

  /* This method is probably not safe to call multiple times concurrently. */
  internal async void _set_postal_addresses (Folks.Persona persona,
      Set<PostalAddressFieldDetails> postal_addresses)
    {
       yield this._set_attrib_set (persona, postal_addresses,
          Trf.Attrib.POSTAL_ADDRESSES);
    }

  /* This method is safe to call multiple times concurrently. */
  internal async void _set_roles (Folks.Persona persona,
      Set<RoleFieldDetails> roles)
    {
      const string del_t = "DELETE { " +
        " ?p " + Trf.OntologyDefs.NCO_HAS_AFFILIATION + " ?a " +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + "; " +
        " " + Trf.OntologyDefs.NCO_HAS_AFFILIATION + " ?a . " +
        " OPTIONAL { ?a " + Trf.OntologyDefs.NCO_ORG +  " ?o } . " +
        " OPTIONAL { ?a " + Trf.OntologyDefs.NCO_ROLE + " ?r } . " +
        " OPTIONAL { ?a " + Trf.OntologyDefs.NCO_TITLE + " ?t } . " +
        " FILTER(tracker:id(?p) = %s) " +
        "} ";

      var p_id = ((Trf.Persona) persona).tracker_id;
      string del_q = del_t.printf (p_id);

      var builder = new Tracker.Sparql.Builder.update ();
      builder.insert_open (null);

      int i = 0;
      foreach (var role_fd in roles)
        {
          string affl = "_:a%d".printf (i);

          builder.subject (affl);
          builder.predicate ("a");
          builder.object (Trf.OntologyDefs.NCO_AFFILIATION);
          builder.predicate (Trf.OntologyDefs.NCO_ROLE);
          builder.object_string (role_fd.value.role);
          builder.predicate (Trf.OntologyDefs.NCO_TITLE);
          builder.object_string (role_fd.value.title);
          builder.predicate (Trf.OntologyDefs.NCO_ORG);
          builder.object_string (role_fd.value.organisation_name);
          builder.subject ("?contact");
          builder.predicate (Trf.OntologyDefs.NCO_HAS_AFFILIATION);
          builder.object (affl);
        }

      builder.insert_close ();
      builder.where_open ();
      builder.subject ("?contact");
      builder.predicate ("a");
      builder.object (Trf.OntologyDefs.NCO_PERSON);
      string filter = " FILTER(tracker:id(?contact) = %s) ".printf (p_id);
      builder.append (filter);
      builder.where_close ();

      yield this._tracker_update (del_q + builder.result, "_set_roles");
   }

  /* This method is safe to call multiple times concurrently. */
  internal async void _set_notes (Folks.Persona persona,
      Set<NoteFieldDetails> notes)
    {
      const string del_t = "DELETE { " +
        "?p " + Trf.OntologyDefs.NCO_NOTE  + " ?n " +
        "} " +
        "WHERE {" +
        " ?p a nco:PersonContact ; " +
        Trf.OntologyDefs.NCO_NOTE + " ?n . " +
        " FILTER(tracker:id(?p) = %s)" +
        "}";

      var p_id = ((Trf.Persona) persona).tracker_id;
      string del_q = del_t.printf (p_id);

      var builder = new Tracker.Sparql.Builder.update ();
      builder.insert_open (null);

      foreach (var n in notes)
        {
          builder.subject ("?contact");
          builder.predicate (Trf.OntologyDefs.NCO_NOTE);
          builder.object_string (n.value);
        }

      builder.insert_close ();
      builder.where_open ();
      builder.subject ("?contact");
      builder.predicate ("a");
      builder.object (Trf.OntologyDefs.NCO_PERSON);
      string filter = " FILTER(tracker:id(?contact) = %s) ".printf (p_id);
      builder.append (filter);
      builder.where_close ();

      yield this._tracker_update (del_q + builder.result, "_set_notes");
    }

  /* This method is safe to call multiple times concurrently. */
  internal async void _set_birthday (Folks.Persona persona,
      owned DateTime bday)
    {
      const string q_t = "DELETE { " +
         " ?p " + Trf.OntologyDefs.NCO_BIRTHDAY + " ?b " +
         "} " +
         "WHERE { " +
         " ?p a " + Trf.OntologyDefs.NCO_PERSON + "; " +
         Trf.OntologyDefs.NCO_BIRTHDAY + " ?b . " +
         " FILTER (tracker:id(?p) = %s ) " +
         "} " +
         "INSERT { " +
         " ?p " + Trf.OntologyDefs.NCO_BIRTHDAY + " '%s' " +
         "} " +
         "WHERE { " +
         " ?p a " + Trf.OntologyDefs.NCO_PERSON + " . " +
         " FILTER (tracker:id(?p) = %s) " +
         "} ";

      var p_id = ((Trf.Persona) persona).tracker_id;
      TimeVal tv;
      bday.to_timeval (out tv);
      string query = q_t.printf (p_id, tv.to_iso8601 (), p_id);

      yield this._tracker_update (query, "_set_birthday");
    }

  /* This method is safe to call multiple times concurrently. */
  internal async void _set_gender (Folks.Persona persona,
      owned Gender gender)
    {
      const string del_t = "DELETE { " +
        " ?p " + Trf.OntologyDefs.NCO_GENDER + " ?g " +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " ; " +
        Trf.OntologyDefs.NCO_GENDER + " ?g . " +
        " FILTER (tracker:id(?p) = %s) " +
        "} ";
      const string ins_t = "INSERT { " +
        " ?p " + Trf.OntologyDefs.NCO_GENDER + " %s " +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON +  " . " +
        " FILTER (tracker:id(?p) = %s) " +
        "} ";

      var p_id = ((Trf.Persona) persona).tracker_id;
      string query;

      if (gender == Gender.UNSPECIFIED)
        {
          query = del_t.printf (p_id);
        }
      else
        {
          string gender_urn;

          if (gender == Gender.MALE)
            gender_urn = Trf.OntologyDefs.NCO_URL_PREFIX + "nco#gender-male>";
          else
            gender_urn = Trf.OntologyDefs.NCO_URL_PREFIX + "nco#gender-female>";

          query = del_t.printf (p_id) + ins_t.printf (gender_urn, p_id);
        }

      yield this._tracker_update (query, "_set_gender");
    }

  /* This method is not safe to call multiple times concurrently. */
  internal async void _set_avatar (Folks.Persona persona,
      LoadableIcon? avatar)
    {
      const string query_d = "DELETE {" +
        " ?c " + Trf.OntologyDefs.NCO_PHOTO  + " ?p " +
        " } " +
        "WHERE { " +
        " ?c a " + Trf.OntologyDefs.NCO_PERSON  + " ; " +
        Trf.OntologyDefs.NCO_PHOTO + " ?p . " +
        " FILTER(tracker:id(?c) = %s) " +
        "} ";

      const string query_i = "INSERT { " +
        " _:i a " + Trf.OntologyDefs.NFO_IMAGE  + ", " +
        Trf.OntologyDefs.NIE_DATAOBJECT + " ; " +
        Trf.OntologyDefs.NIE_URL + " '%s' . " +
        " ?c " + Trf.OntologyDefs.NCO_PHOTO + " _:i " +
        "} " +
        "WHERE { " +
        " ?c a nco:PersonContact . " +
        " FILTER(tracker:id(?c) = %s) " +
        "}";

      var p_id = ((Trf.Persona) persona).tracker_id;

      var image_urn = yield this._get_property (int.parse (p_id),
          Trf.OntologyDefs.NCO_PHOTO);
      if (image_urn != "")
        this._delete_resource.begin ("<%s>".printf (image_urn));

      string query = query_d.printf (p_id);

      var cache = AvatarCache.dup ();
      if (avatar != null)
        {
          try
            {
              // Cache the avatar so that it has a URI
              var uri = yield cache.store_avatar (persona.uid, avatar);

              // Add the avatar to the query
              query += query_i.printf (uri , p_id);
            }
          catch (GLib.Error e1)
            {
              warning ("Couldn't cache avatar for Trf.Persona '%s': %s",
                  persona.uid, e1.message);
            }
        }
      else
        {
          // Delete any old avatar from the cache, ignoring errors
          try
            {
              yield cache.remove_avatar (persona.uid);
            }
          catch (GLib.Error e2) {}
        }

      yield this._tracker_update (query, "_set_avatar");
    }

  /* This method is safe to call multiple times concurrently. */
  internal async void _set_structured_name (Folks.Persona persona,
      StructuredName? sname)
    {
      const string query_d = "DELETE { " +
        " ?p " + Trf.OntologyDefs.NCO_FAMILY + " ?family . " +
        " ?p " + Trf.OntologyDefs.NCO_GIVEN + " ?given . " +
        " ?p " + Trf.OntologyDefs.NCO_ADDITIONAL + " ?adi . " +
        " ?p " + Trf.OntologyDefs.NCO_PREFIX + " ?prefix . " +
        " ?p " + Trf.OntologyDefs.NCO_SUFFIX + " ?suffix " +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " .  " +
        " OPTIONAL { ?p " + Trf.OntologyDefs.NCO_FAMILY + " ?family } . " +
        " OPTIONAL { ?p " + Trf.OntologyDefs.NCO_GIVEN + " ?given } . " +
        " OPTIONAL { ?p " + Trf.OntologyDefs.NCO_ADDITIONAL + " ?adi } . " +
        " OPTIONAL { ?p " + Trf.OntologyDefs.NCO_PREFIX + " ?prefix } . " +
        " OPTIONAL { ?p " + Trf.OntologyDefs.NCO_SUFFIX + " ?suffix } . " +
        " FILTER (tracker:id(?p) = %s) " +
        "} ";
      const string query_i = "INSERT { " +
        " ?p " + Trf.OntologyDefs.NCO_FAMILY + " '%s'; " +
        " " + Trf.OntologyDefs.NCO_GIVEN + " '%s'; " +
        " " + Trf.OntologyDefs.NCO_ADDITIONAL + " '%s'; " +
        " " + Trf.OntologyDefs.NCO_PREFIX + " '%s'; " +
        " " + Trf.OntologyDefs.NCO_SUFFIX + " '%s' " +
        " } " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " . " +
        " FILTER (tracker:id(?p) = %s) " +
        "} ";

      var p_id = ((Trf.Persona) persona).tracker_id;

      string query = query_d.printf (p_id);
      if (sname != null)
        {
          query = query_i.printf (sname.family_name, sname.given_name,
              sname.additional_names, sname.prefixes, sname.suffixes, p_id);
        }

      yield this._tracker_update (query, "_set_structured_name");
    }

  /* This method is safe to call multiple times concurrently. */
  internal async void _set_full_name  (Folks.Persona persona,
      string full_name)
    {
      const string query_t = "DELETE { " +
        " ?p " + Trf.OntologyDefs.NCO_FULLNAME + " ?fn " +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " .  " +
        " OPTIONAL { ?p " + Trf.OntologyDefs.NCO_FULLNAME + " ?fn } . " +
        " FILTER (tracker:id(?p) = %s) " +
        "} " +
        "INSERT { " +
        " ?p " + Trf.OntologyDefs.NCO_FULLNAME + " '%s' " +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " . " +
        " FILTER (tracker:id(?p) = %s) " +
        "} ";

      var p_id = ((Trf.Persona) persona).tracker_id;
      string query = query_t.printf (p_id, full_name, p_id);
      yield this._tracker_update (query, "_set_full_name");
    }

  /* NOTE:
   * - first we nuke old attribs
   * - we create new affls with the new attribs
   *
   * This method is probably not safe to call multiple times concurrently.
   */
  private async void _set_attrib_set (Folks.Persona persona,
      Set<Object> attribs, Trf.Attrib what)
    {
      var p_id = ((Trf.Persona) persona).tracker_id;

      unowned string? related_attrib = null;
      unowned string? related_prop = null;
      unowned string? related_prop_2 = null;
      unowned string? related_connection = null;

      switch (what)
        {
          case Trf.Attrib.IM_ADDRESSES:
            related_attrib = Trf.OntologyDefs.NCO_IMADDRESS;
            related_prop = Trf.OntologyDefs.NCO_IMID;
            related_prop_2 = Trf.OntologyDefs.NCO_IMPROTOCOL;
            related_connection = Trf.OntologyDefs.NCO_HAS_IMADDRESS;
            yield this._remove_attributes_from_persona (persona,
                _REMOVE_IM_ADDRS);
            break;
          case Trf.Attrib.POSTAL_ADDRESSES:
            related_attrib = Trf.OntologyDefs.NCO_POSTAL_ADDRESS;
            related_connection = Trf.OntologyDefs.NCO_HAS_POSTAL_ADDRESS;
            yield this._remove_attributes_from_persona (persona,
                _REMOVE_POSTALS);
            break;
          case Trf.Attrib.URLS:
            related_attrib = Trf.OntologyDefs.NCO_URL;
            related_connection = Trf.OntologyDefs.NCO_URL;
            break;
        }

      var builder = new Tracker.Sparql.Builder.update ();
      builder.insert_open (null);
      int i = 0;
      foreach (var p in attribs)
        {
          AbstractFieldDetails fd = null;
          PostalAddressFieldDetails pafd = null;
          PostalAddress pa = null;

          string affl = "_:a%d".printf (i);
          string attr = null;

          switch (what)
            {
              case Trf.Attrib.POSTAL_ADDRESSES:
                pafd = (PostalAddressFieldDetails) p;
                pa = pafd.value;
                attr = "_:p%d".printf (i);
                builder.subject (attr);
                builder.predicate ("a");
                builder.object (related_attrib);
                builder.predicate (Trf.OntologyDefs.NCO_POBOX);
                builder.object_string (pa.po_box);
                builder.predicate (Trf.OntologyDefs.NCO_LOCALITY);
                builder.object_string (pa.locality);
                builder.predicate (Trf.OntologyDefs.NCO_POSTALCODE);
                builder.object_string (pa.postal_code);
                builder.predicate (Trf.OntologyDefs.NCO_STREET_ADDRESS);
                builder.object_string (pa.street);
                builder.predicate (Trf.OntologyDefs.NCO_EXTENDED_ADDRESS);
                builder.object_string (pa.extension);
                builder.predicate (Trf.OntologyDefs.NCO_COUNTRY);
                builder.object_string (pa.country);
                builder.predicate (Trf.OntologyDefs.NCO_REGION);
                builder.object_string (pa.region);
                break;
              case Trf.Attrib.URLS:
                fd = (UrlFieldDetails) p;
                var type_p = fd.get_parameter_values (AbstractFieldDetails.PARAM_TYPE);

                if (type_p != null &&
                    type_p.contains (UrlFieldDetails.PARAM_TYPE_BLOG))
                  {
                    related_connection = Trf.OntologyDefs.NCO_BLOG;
                  }
                else if (type_p != null &&
                    type_p.contains (UrlFieldDetails.PARAM_TYPE_HOME_PAGE))
                  {
                    related_connection = Trf.OntologyDefs.NCO_WEBSITE;
                  }
                else
                  {
                    related_connection = Trf.OntologyDefs.NCO_URL;
                  }

                attr = "'%s'".printf (((UrlFieldDetails) fd).value);
                break;
              case Trf.Attrib.IM_ADDRESSES:
              default:
                fd = (ImFieldDetails) p;
                attr = "_:p%d".printf (i);
                builder.subject (attr);
                builder.predicate ("a");
                builder.object (related_attrib);
                builder.predicate (related_prop);
                builder.object_string (((ImFieldDetails) fd).value);

                if (what == Trf.Attrib.IM_ADDRESSES)
                  {
                    builder.predicate (related_prop_2);
                    var im_params =
                        fd.get_parameter_values ("proto").to_array ();
                    builder.object_string (im_params[0]);
                  }

                break;
            }

          builder.subject (affl);
          builder.predicate ("a");
          builder.object (Trf.OntologyDefs.NCO_AFFILIATION);
          builder.predicate (related_connection);
          builder.object (attr);
          builder.subject ("?contact");
          builder.predicate (Trf.OntologyDefs.NCO_HAS_AFFILIATION);
          builder.object (affl);

          i++;
        }
      builder.insert_close ();
      builder.where_open ();
      builder.subject ("?contact");
      builder.predicate ("a");
      builder.object (Trf.OntologyDefs.NCO_PERSON);
      string filter = " FILTER(tracker:id(?contact) = %s) ".printf (p_id);
      builder.append (filter);
      builder.where_close ();

      yield this._tracker_update (builder.result, "set_attrib");
    }

  /* This method is safe to call multiple times concurrently. */
  private async bool _tracker_update (string query, string caller)
    {
      bool ret = false;

      debug ("%s: %s", caller, query);

      try
        {
          yield this._connection.update_async (query);
          ret = true;
        }
      catch (Tracker.Sparql.Error e1)
        {
          warning ("[%s] SPARQL syntax error: %s. Query: %s",
              caller, e1.message, query);
        }
      catch (GLib.IOError e2)
        {
          warning ("[%s] IO error: %s",
              caller, e2.message);
        }
      catch (GLib.DBusError e3)
        {
          warning ("[%s] DBus error: %s",
              caller, e3.message);
        }

      return ret;
    }

  /* This method is safe to call multiple times concurrently. */
  private async SmallSet<string> _affiliations_from_persona (string urn)
    {
      return yield this._linked_resources (urn, Trf.OntologyDefs.NCO_PERSON,
          Trf.OntologyDefs.NCO_HAS_AFFILIATION);
    }

  /* This method is safe to call multiple times concurrently. */
  private async SmallSet<string> _phones_from_affiliation (string affl)
    {
      return yield this._linked_resources (affl,
          Trf.OntologyDefs.NCO_AFFILIATION,
          Trf.OntologyDefs.NCO_HAS_PHONE);
    }

  /* This method is safe to call multiple times concurrently. */
  private async SmallSet<string>  _postals_from_affiliation (string affl)
    {
      return yield this._linked_resources (affl,
          Trf.OntologyDefs.NCO_AFFILIATION,
          Trf.OntologyDefs.NCO_HAS_POSTAL_ADDRESS);
    }

  /* This method is safe to call multiple times concurrently. */
  private async SmallSet<string> _imaddrs_from_affiliation  (string affl)
    {
      return yield this._linked_resources (affl,
          Trf.OntologyDefs.NCO_AFFILIATION,
          Trf.OntologyDefs.NCO_HAS_IMADDRESS);
    }

  /* This method is safe to call multiple times concurrently. */
  private async SmallSet<string> _emails_from_affiliation (string affl)
    {
      return yield this._linked_resources (affl,
          Trf.OntologyDefs.NCO_AFFILIATION,
          Trf.OntologyDefs.NCO_HAS_EMAIL);
    }

  /**
   * Retrieve the list of linked resources of a given subject
   *
   * This method is safe to call multiple times concurrently.
   *
   * @param resource          the urn of the resource in <urn> format
   * @return number of resources linking to this resource
   */
  private async int _resource_usage_count (string resource)
    {
      const string query_t = "SELECT " +
        " count(?s) " +
        "WHERE { " +
        " %s a rdfs:Resource . " +
        " ?s ?p %s } ";

      var query = query_t.printf (resource, resource);
      var result = yield this._single_value_query (query);
      return int.parse (result);
    }

  /*
   * NOTE:
   *
   * We asume that the caller is holding a link to the resource,
   * so if _resource_usage_count () == 1 it means no one else
   * (beside the caller) is linking to the resource.
   *
   * This means that _delete_resource shold be called before
   * removing the resources that hold a link to it (which also
   * makes sense from the signaling perspective).
   *
   * This method is not safe to call multiple times concurrently, as the
   * resource count check races with deletion.
   */
  private async bool _delete_resource (string resource_urn,
      bool check_count = true)
    {
      bool deleted = false;
      var query_t = " DELETE { " +
        " %s a rdfs:Resource " +
        "} " +
        "WHERE { " +
        " %s a rdfs:Resource " +
        "} ";

      var query = query_t.printf (resource_urn, resource_urn);
      if (check_count)
        {
          int count = yield this._resource_usage_count (resource_urn);
          if (count == 1)
            {
              deleted = yield this._tracker_update (query, "_delete_resource");
            }
        }
      else
        {
          deleted = yield this._tracker_update (query, "_delete_resource");
        }

      return deleted;
    }

  /**
   * Retrieve the list of linked resources of a given subject
   *
   * This method is safe to call multiple times concurrently.
   *
   * @param urn               the urn of the subject in <urn> format
   * @param subject_type      i.e: nco:Person, nco:Affiliation, etc
   * @param linking_predicate i.e.: nco:hasAffiliation
   * @return a list of linked resources (in <urn> format)
   */
  private async SmallSet<string> _linked_resources (string urn,
      string subject_type, string linking_predicate)
    {
      string query_t = "SELECT " +
        " fn:concat('<',?linkedr,'>')  " +
        "WHERE { " +
        " %s a %s; " +
        " %s ?linkedr " +
        "} ";

      var query = query_t.printf (urn, subject_type, linking_predicate);
      return yield this._multi_value_query (query);
    }

  /* This method is safe to call multiple times concurrently. */
  private async string _urn_from_persona (Folks.Persona persona)
    {
      var id = ((Trf.Persona) persona).tracker_id;
      return yield this._urn_from_tracker_id (id);
    }

  /**
   * Helper method to figure out if a constrained property
   * already exists.
   *
   * This method is safe to call multiple times concurrently.
   */
  private async string _urn_from_property (string class_name,
      string property_name,
      string property_value)
    {
      const string query_template = "SELECT " +
        " fn:concat('<', ?o, '>') " +
        "WHERE { " +
        " ?o a %s ; " +
        " %s ?prop_val . " +
        "FILTER (?prop_val = '%s') " +
        "}";

      string query = query_template.printf (class_name,
          property_name, property_value);
      return yield this._single_value_query (query);
    }
}
