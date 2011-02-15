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
  POSTAL_ADDRESS
}

internal enum Trf.AfflInfoFields
{
  IM_TRACKER_ID,
  IM_PROTOCOL,
  IM_ACCOUNT_ID,
  AFFL_TRACKER_ID,
  AFFL_ROLE,
  AFFL_ORG,
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
  AFFL_URL
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
  DEPARTMENT
}

internal enum Trf.IMFields
{
  TRACKER_ID,
  PROTO,
  ID
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

/**
 * A persona store.
 * It will create {@link Persona}s for each contacts on the main addressbook.
 */
public class Trf.PersonaStore : Folks.PersonaStore
{
  private const string _OBJECT_NAME = "org.freedesktop.Tracker1";
  private const string _OBJECT_IFACE = "org.freedesktop.Tracker1.Resources";
  private const string _OBJECT_PATH = "/org/freedesktop/Tracker1/Resources";
  private HashTable<string, Persona> _personas;
  private bool _is_prepared = false;
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
    "'\t', tracker:coalesce(nco:imID(?a),'')),'\\n') " +
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
    "  tracker:coalesce(nco:department(?affl),'')),  " +
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

    "{ ?_contact a nco:PersonContact . } " +
    "ORDER BY tracker:id(?_contact) ";


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
   * @since UNRELEASED
   */
  public override MaybeBool can_add_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore can set the alias of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_alias_personas}.
   *
   * @since UNRELEASED
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
   * @since UNRELEASED
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
   * @since UNRELEASED
   */
  public override MaybeBool can_remove_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore has been prepared.
   *
   * See {@link Folks.PersonaStore.is_prepared}.
   *
   * @since UNRELEASED
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * The {@link Persona}s exposed by this PersonaStore.
   *
   * See {@link Folks.PersonaStore.personas}.
   */
  public override HashTable<string, Persona> personas
    {
      get { return this._personas; }
    }

  /**
   * Create a new PersonaStore.
   *
   * Create a new persona store to store the {@link Persona}s for the contacts
   */
  public PersonaStore ()
    {
      Object (id: BACKEND_NAME, display_name: BACKEND_NAME);
      this._personas = new HashTable<string, Persona> (str_hash, str_equal);
      debug ("Initial query : \n%s\n", this._INITIAL_QUERY);
    }

  /**
   * Add a new {@link Persona} to the PersonaStore.
   *
   * See {@link Folks.PersonaStore.add_persona_from_details}.
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      throw new PersonaStoreError.READ_ONLY (
          "Personas cannot be added to this store.");
    }

  /**
   * Remove a {@link Persona} from the PersonaStore.
   *
   * See {@link Folks.PersonaStore.remove_persona}.
   */
  public override async void remove_persona (Folks.Persona persona)
      throws Folks.PersonaStoreError
    {
      throw new PersonaStoreError.READ_ONLY (
          "Personas cannot be removed from this store.");
    }

  /**
   * Prepare the PersonaStore for use.
   *
   * TODO: we should throw different errors dependening on what went wrong
   *       when we were trying to setup the PersonaStore.
   *
   * See {@link Folks.PersonaStore.prepare}.
   */
  public override async void prepare () throws GLib.Error
    {
      lock (this._is_prepared)
        {
          if (!this._is_prepared)
            {
              try
                {
                  this._connection = Tracker.Sparql.Connection.get ();

                  yield this._build_predicates_table ();
                  yield this._do_add_contacts (this._INITIAL_QUERY);

                  /* Don't add a match rule for all signals from Tracker but
                   * only for GraphUpdated with the specific class we need. We
                   * don't want to be woken up for irrelevent updates on the
                   * graph.
                   */
                  this._resources_object = yield GLib.Bus.get_proxy<Resources> (
                      BusType.SESSION,
                      this._OBJECT_NAME,
                      this._OBJECT_PATH,
                      DBusProxyFlags.DO_NOT_CONNECT_SIGNALS |
                        DBusProxyFlags.DO_NOT_LOAD_PROPERTIES);
                  this._resources_object.g_connection.signal_subscribe
                      (this._OBJECT_NAME, this._OBJECT_IFACE,
                      "GraphUpdated", this._OBJECT_PATH,
                      Trf.OntologyDefs.PERSON_CLASS, GLib.DBusSignalFlags.NONE,
                      this._graph_updated_cb);
                }
              catch (GLib.IOError e1)
                {
                  warning ("Could not connect to D-Bus service: %s",
                           e1.message);
                  throw new PersonaStoreError.INVALID_ARGUMENT (e1.message);
                }
              catch (Tracker.Sparql.Error e2)
                {
                  warning ("Error fetching SPARQL connection handler: %s",
                           e2.message);
                  throw new PersonaStoreError.INVALID_ARGUMENT (e2.message);
                }
              catch (GLib.DBusError e3)
                {
                  warning ("Could not connect to D-Bus service: %s",
                           e3.message);
                  throw new PersonaStoreError.INVALID_ARGUMENT (e3.message);
                }
            }
        }
    }

  public int get_favorite_id ()
    {
      return this._prefix_tracker_id.get
          (Trf.OntologyDefs.NAO_FAVORITE);
    }

  public int get_gender_male_id ()
    {
      return this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_MALE);
    }

  public int get_gender_female_id ()
    {
      return this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_FEMALE);
    }

  private async void _build_predicates_table ()
    {
      if (this._prefix_tracker_id != null)
        {
          return;
        }

      yield this._build_urn_prefix_table ();

      this._prefix_tracker_id = new Gee.TreeMap<string, int> ();

      string query = "SELECT  ";
      foreach (var urn_t in this._urn_prefix.keys)
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
              foreach (var urn in this._urn_prefix.keys)
                {
                  var tracker_id = (int) cursor.get_integer (i);
                  var prefix = this._urn_prefix.get (urn).dup ();
                  this._prefix_tracker_id.set (prefix, tracker_id);
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

  private async void _build_urn_prefix_table ()
    {
      if (this._urn_prefix != null)
        {
          return;
        }
      this._urn_prefix = new Gee.TreeMap<string, string> ();
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#fullname>",
          Trf.OntologyDefs.NCO_FULLNAME);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nameFamily>",
          Trf.OntologyDefs.NCO_FAMILY);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nameGiven>",
          Trf.OntologyDefs.NCO_GIVEN);
      this._urn_prefix.set (
          Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nameAdditional>",
          Trf.OntologyDefs.NCO_ADDITIONAL);
      this._urn_prefix.set (
          Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nameHonorificSuffix>",
          Trf.OntologyDefs.NCO_SUFFIX);
      this._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nameHonorificPrefix>",
         Trf.OntologyDefs.NCO_PREFIX);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nickname>",
         Trf.OntologyDefs.NCO_NICKNAME);
      this._urn_prefix.set (
         Trf.OntologyDefs.RDF_URL_PREFIX + "22-rdf-syntax-ns#type>",
         Trf.OntologyDefs.RDF_TYPE);
      this._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#PersonContact>",
         Trf.OntologyDefs.NCO_PERSON);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#websiteUrl>",
         Trf.OntologyDefs.NCO_WEBSITE);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#blogUrl>",
         Trf.OntologyDefs.NCO_BLOG);
      this._urn_prefix.set (
         Trf.OntologyDefs.NAO_URL_PREFIX + "nao#predefined-tag-favorite>",
         Trf.OntologyDefs.NAO_FAVORITE);
      this._urn_prefix.set (Trf.OntologyDefs.NAO_URL_PREFIX + "nao#hasTag>",
         Trf.OntologyDefs.NAO_TAG);
      this._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#hasEmailAddress>",
         Trf.OntologyDefs.NCO_HAS_EMAIL);
      this._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#hasPhoneNumber>",
         Trf.OntologyDefs.NCO_HAS_PHONE);
      this._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#hasAffiliation>",
         Trf.OntologyDefs.NCO_HAS_AFFILIATION);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#birthDate>",
         Trf.OntologyDefs.NCO_BIRTHDAY);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#note>",
         Trf.OntologyDefs.NCO_NOTE);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#gender>",
         Trf.OntologyDefs.NCO_GENDER);
      this._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#gender-male>",
         Trf.OntologyDefs.NCO_MALE);
      this._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#gender-female>",
         Trf.OntologyDefs.NCO_FEMALE);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#photo>",
         Trf.OntologyDefs.NCO_PHOTO);
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

      var removed_personas = new Queue<Persona> ();
      var added_personas = new Queue<Persona> ();

      var nco_person_id =
          this._prefix_tracker_id.get (Trf.OntologyDefs.NCO_PERSON);
      var rdf_type_id = this._prefix_tracker_id.get (Trf.OntologyDefs.RDF_TYPE);

      Event e = Event ();

      while (iter_del.next
          ("(iiii)", &e.graph_id, &e.subject_id, &e.pred_id, &e.object_id))
        {
          var p_id = Trf.Persona.build_iid (this.id, e.subject_id.to_string ());
          var persona = this._personas.lookup (p_id);
          if (persona != null)
            {
              if (e.pred_id == rdf_type_id &&
                  e.object_id == nco_person_id)
                {
                  removed_personas.push_tail (persona);
                  _personas.remove (persona.iid);
                }
              else
                {
                  this._do_update (persona, e, false);
                }
            }
        }

      while (iter_ins.next
          ("(iiii)", &e.graph_id, &e.subject_id, &e.pred_id, &e.object_id))
        {
          var subject_tracker_id = e.subject_id.to_string ();
          var p_id = Trf.Persona.build_iid (this.id, subject_tracker_id);
          var persona = this._personas.lookup (p_id);
          if (persona == null)
            {
              persona = new Trf.Persona (this, subject_tracker_id);
              this._personas.insert (persona.iid, persona);
              added_personas.push_tail (persona);
            }
          this._do_update (persona, e);
        }

      if (removed_personas.length > 0)
        {
          this.personas_changed (null, removed_personas.head, null, null, 0);
        }

      if (added_personas.length > 0)
        {
          this.personas_changed (added_personas.head, null, null, null, 0);
        }
    }

  private async void _do_add_contacts (string query)
    {
      try {
        var added_personas = new Queue<Persona> ();
        Sparql.Cursor cursor = yield this._connection.query_async (query);

        while (cursor.next ())
          {
            int tracker_id = (int) cursor.get_integer (Trf.Fields.TRACKER_ID);
            var p_id = Trf.Persona.build_iid (this.id, tracker_id.to_string ());
            if (this._personas.lookup (p_id) == null)
              {
                var persona = new Trf.Persona (this,
                    tracker_id.to_string (), cursor);
                this._personas.insert (persona.iid, persona);
                added_personas.push_tail (persona);
              }
          }

        if (added_personas.length > 0)
          {
            this.personas_changed (added_personas.head, null, null, null, 0);
          }
      } catch (GLib.Error e) {
        warning ("Couldn't perform queries: %s %s", query, e.message);
      }
    }

  private void _do_update (Persona p, Event e, bool adding = true)
    {
      if (e.pred_id ==
          this._prefix_tracker_id.get (Trf.OntologyDefs.NCO_FULLNAME))
        {
          string fullname = "";
          if (adding)
            {
              fullname =
              this._get_property (e.subject_id, Trf.OntologyDefs.NCO_FULLNAME);
            }
          p._update_full_name (fullname);
        }
      else if (e.pred_id ==
               this._prefix_tracker_id.get (Trf.OntologyDefs.NCO_NICKNAME))
        {
          string nickname = "";
          if (adding)
            {
              nickname =
                  this._get_property (
                      e.subject_id, Trf.OntologyDefs.NCO_NICKNAME);
            }
          p._update_nickname (nickname);
        }
      else if (e.pred_id ==
               this._prefix_tracker_id.get (Trf.OntologyDefs.NCO_FAMILY))
        {
          string family_name = "";
          if (adding)
            {
              family_name = this._get_property
                  (e.subject_id, Trf.OntologyDefs.NCO_FAMILY);
            }
          p._update_family_name (family_name);
        }
      else if (e.pred_id ==
               this._prefix_tracker_id.get (Trf.OntologyDefs.NCO_GIVEN))
        {
          string given_name = "";
          if (adding)
            {
              given_name = this._get_property (
                  e.subject_id, Trf.OntologyDefs.NCO_GIVEN);
            }
          p._update_given_name (given_name);
        }
      else if (e.pred_id ==
               this._prefix_tracker_id.get (Trf.OntologyDefs.NCO_ADDITIONAL))
        {
          string additional_name = "";
          if (adding)
            {
              additional_name = this._get_property
                  (e.subject_id, Trf.OntologyDefs.NCO_ADDITIONAL);
            }
          p._update_additional_names (additional_name);
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_SUFFIX))
        {
          string suffix_name = "";
          if (adding)
            {
              suffix_name = this._get_property
                  (e.subject_id, Trf.OntologyDefs.NCO_SUFFIX);
            }
          p._update_suffixes (suffix_name);
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_PREFIX))
        {
          string prefix_name = "";
          if (adding)
            {
              prefix_name = this._get_property
                  (e.subject_id, Trf.OntologyDefs.NCO_PREFIX);
            }
          p._update_prefixes (prefix_name);
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          ("nao:hasTag"))
        {
          if (e.object_id == this.get_favorite_id ())
            {
              if (adding)
                {
                  p.is_favourite = true;
                }
              else
                {
                  p.is_favourite = false;
                }
            }
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_HAS_EMAIL))
        {
          if (adding)
            {
              var email = this._get_property (
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
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_HAS_PHONE))
        {
          if (adding)
            {
              var phone = this._get_property (
                  e.object_id, Trf.OntologyDefs.NCO_PHONE_PROP,
                  Trf.OntologyDefs.NCO_PHONE);
              p._add_phone (phone, e.object_id.to_string ());
            }
          else
            {
              p._remove_phone (e.object_id.to_string ());
            }
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_HAS_AFFILIATION))
        {
          if (adding)
            {
              var affl_info = this._get_affl_info (e.subject_id.to_string (),
                  e.object_id.to_string ());

              debug ("affl_info : %s", affl_info.to_string ());

              if (affl_info.im_tracker_id != null)
                {
                  p._add_im_address (affl_info.affl_tracker_id,
                      affl_info.im_proto, affl_info.im_account_id);
                }

              if (affl_info.affl_tracker_id != null)
                {
                  if (affl_info.title != null ||
                      affl_info.org != null)
                    {
                      p._add_role (affl_info.affl_tracker_id, affl_info.title,
                          affl_info.org);
                    }
                }

              if (affl_info.postal_address != null)
                p._add_postal_address (affl_info.postal_address);

              if (affl_info.phone != null)
                p._add_phone (affl_info.phone, e.object_id.to_string ());

              if (affl_info.email != null)
                p._add_email (affl_info.email, e.object_id.to_string ());

              if (affl_info.website != null)
                p._add_url (affl_info.website,
                    affl_info.affl_tracker_id, "website");

              if (affl_info.blog != null)
                p._add_url (affl_info.blog,
                    affl_info.affl_tracker_id, "blog");

              if (affl_info.url != null)
                p._add_url (affl_info.url,
                    affl_info.affl_tracker_id, "url");
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
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_BIRTHDAY))
        {
          string bday = "";
          if (adding)
            {
              bday = this._get_property (
                  e.subject_id, Trf.OntologyDefs.NCO_BIRTHDAY);
            }
          p._set_birthday (bday);
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_NOTE))
        {
          string note = "";
          if (adding)
            {
              note = this._get_property (
                  e.subject_id, Trf.OntologyDefs.NCO_NOTE);
            }
          p._set_note (note);
        }
      else if (e.pred_id == this._prefix_tracker_id.get
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
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_PHOTO))
        {
          string avatar_url = "";
          if (adding)
            {
              avatar_url = this._get_property (e.object_id,
                  Trf.OntologyDefs.NIE_URL, Trf.OntologyDefs.NFO_IMAGE);
            }
          p._set_avatar (avatar_url);
        }
    }

  private string _get_property
      (int subject_tracker_id, string property,
       string subject_type = Trf.OntologyDefs.NCO_PERSON)
    {
      string ret = "";
      const string query_template =
        "SELECT ?property WHERE" +
        " { ?p a %s ; " +
        "   %s ?property " +
        " . FILTER(tracker:id(?p) = %d ) }";

      string query = query_template.printf (subject_type,
          property, subject_tracker_id);

      try
        {
          Sparql.Cursor cursor = this._connection.query (query);
          while (cursor.next ())
            {
              var prop = cursor.get_string (0);
              if (prop != null)
                {
                  ret = prop.dup ();
                }
            }
        }
      catch (Tracker.Sparql.Error e1)
        {
          warning ("Couldn't fetch propery: %s %s", query, e1.message);
        }
      catch (GLib.Error e2)
        {
          warning ("Couldn't fetch property: %s %s", query, e2.message);
        }

      return ret;
    }

  /*
   * This should be kept in sync with Trf.AfflInfoFields
   */
  private Trf.AfflInfo _get_affl_info (
      string person_id, string affiliation_id)
    {
      Trf.AfflInfo affl_info = new Trf.AfflInfo ();
      const string query_template =
        "SELECT " +
        "tracker:id(?i) " +
        "nco:imProtocol(?i) " +
        "nco:imID(?i) " +
        "tracker:id(?a) " +
        "nco:role(?a) " +
        "nco:org(?a) " +
        "nco:pobox(?postal) " +
        "nco:district(?postal) " +
        "nco:county(?postal) " +
        "nco:locality(?postal) " +
        "nco:postalcode(?postal) " +
        "nco:streetAddress(?postal) " +
        "nco:addressLocation(?postal) " +
        "nco:extendedAddress(?postal) " +
        "nco:country(?postal) " +
        "nco:region(?postal) " +
        "nco:emailAddress(?e) " +
        "nco:phoneNumber(?number) " +
        "nco:websiteUrl(?a) " +
        "nco:blogUrl(?a) " +
        "nco:url(?a) " +
        " WHERE { ?p a nco:PersonContact ; nco:hasAffiliation ?a . " +
        " OPTIONAL { ?a nco:hasIMAddress ?i } . " +
        " OPTIONAL { ?a nco:hasPostalAddress ?postal } . " +
        " OPTIONAL { ?a nco:hasEmailAddress ?e } . " +
        " OPTIONAL { ?a nco:hasPhoneNumber ?number }  " +
        " FILTER(tracker:id(?p) = %s" +
        " && tracker:id(?a) = %s" +
        " ) } ";

      string query = query_template.printf (person_id, affiliation_id);

      debug ("_get_affl_info: %s", query);

      try
        {
          Sparql.Cursor cursor = this._connection.query (query);
          while (cursor.next ())
            {
              affl_info.im_tracker_id = cursor.get_string
                  (Trf.AfflInfoFields.IM_TRACKER_ID).dup ();
              affl_info.im_proto = cursor.get_string
                  (Trf.AfflInfoFields.IM_PROTOCOL).dup ();
              affl_info.im_account_id = cursor.get_string
                  (Trf.AfflInfoFields.IM_ACCOUNT_ID).dup ();
              affl_info.affl_tracker_id = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_TRACKER_ID).dup ();
              affl_info.title = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_ROLE).dup ();
              affl_info.org = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_ORG).dup ();

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

              List<string> types = new List<string> ();

              affl_info.postal_address = new Folks.PostalAddress (
                  po_box, extension, street, locality, region, postal_code,
                  country, null, (owned) types, affl_info.affl_tracker_id);

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
}
