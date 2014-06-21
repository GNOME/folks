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
 * Authors :Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *
 */

using Tracker;
using Tracker.Sparql;

errordomain TrackerTest.BackendSetupError
{
  ADD_CONTACT_FAILED,
}

public class TrackerTest.Backend
{
  public static const string URN = "urn:contact";
  public static const string URLS = "nco:urls";
  public bool debug { get; set; }
  private GLib.List<Gee.HashMap<string, string>> _contacts;
  private Tracker.Sparql.Connection? _connection;


  public Backend ()
    {
      this.debug = false;
      this._contacts = new GLib.List<Gee.HashMap<string, string>> ();
   }

  public void add_contact (Gee.HashMap<string, string> c)
    {
      var contact = this._copy_hash_map (c);
      this._contacts.prepend (contact);
    }

  /* Remove contacts */
  public void tear_down ()
    {
      this.reset ();
      this._connection = null;
    }

  public void reset ()
    {
      this._contacts = new GLib.List<Gee.HashMap<string, string>> ();
    }

  /* Insert contacts */
  public void set_up ()
    {
      try
        {
          this._setup_connection ();
          this._add_contacts ();
        }
      catch (BackendSetupError e)
        {
          GLib.warning ("unable to create test data: %s\n", e.message);
        }
    }

  public bool update_contact (string contact_urn, string predicate,
                              string literal_subject)
    {
      const string delete_query_t = "DELETE { %s %s ?a } WHERE " +
          "{ ?p a nco:PersonContact " +
          " ; %s ?a . FILTER(?p = %s ) } ";
      const string update_query_t = "INSERT { %s %s '%s' } ";

      string delete_query = delete_query_t.printf (contact_urn, predicate,
          predicate, contact_urn);
      if (this._do_update_query (delete_query) == false)
        {
          GLib.warning ("Couldn't delete the old triplet");
          return false;
        }

      string update_query = update_query_t.printf (contact_urn, predicate,
          literal_subject);
      if (this._do_update_query (update_query) == false)
        {
          GLib.warning ("Couldn't insert the triplet");
          return false;
        }

      return true;
    }

  public bool update_favourite (string contact_urn, bool is_favourite)
    {
      string q = "";

      if (is_favourite)
        {
          q += "INSERT { ";
        }
      else
        {
          q += "DELETE { ";
        }
      q += contact_urn + " nao:hasTag nao:predefined-tag-favorite } ";

      if (this._do_update_query (q) == false)
        {
          GLib.warning ("Couldn't change favourite status");
          return false;
        }

      return true;
    }

  public bool remove_contact (string tracker_id)
    {
      string delete_query = "DELETE { ?p a nco:PersonContact } ";
      delete_query += "WHERE { ?p a nco:PersonContact . FILTER(tracker:id(?p) ";
      delete_query += "= " + tracker_id + ") } ";

      if (this._do_update_query (delete_query) == false)
        {
          GLib.warning ("Couldn't delete the contact");
          return false;
        }

      return true;
    }

  public bool remove_triplet (string subject_urn, string pred,
      string object_urn)
    {
      var builder = new Tracker.Sparql.Builder.update ();
      builder.delete_open (null);
      builder.subject (subject_urn);
      builder.predicate (pred);
      builder.object (object_urn);
      builder.delete_close ();

      if (this._do_update_query (builder.result) == false)
        {
          GLib.warning ("Couldn't delete triplet with query: %s\n",
              builder.result);
          return false;
        }

      return true;
    }

  public bool insert_triplet (string subject_iri, string pred,
      string object_iri,
      string? pred_b = null, string? obj_literal_b = null,
      string? pred_c = null, string? obj_literal_c = null)
    {
      var builder = new Tracker.Sparql.Builder.update ();
      builder.insert_open (null);
      builder.subject (subject_iri);
      builder.predicate (pred);
      builder.object (object_iri);

      if (pred_b != null)
        {
          builder.predicate (pred_b);
          builder.object_string (obj_literal_b);
        }

      if (pred_c != null)
        {
          builder.predicate (pred_c);
          builder.object_string (obj_literal_c);
        }

      builder.insert_close ();

      if (this._do_update_query (builder.result) == false)
        {
          GLib.warning ("Couldn't insert triplet with query: %s\n",
              builder.result);
          return false;
        }

      return true;
    }

  private bool _do_update_query (string query)
    {
      bool ret = false;

      if (this.debug)
        {
          GLib.stdout.printf ("_do_update_query : %s\n", query);
        }

      try
        {
          this._connection.update (query);
          ret = true;
        }
      catch (Tracker.Sparql.Error e1)
        {
          GLib.warning ("Problem getting connection : %s\n", e1.message);
        }
      catch (GLib.IOError e2)
        {
          GLib.warning ("Problem saving data : %s\n", e2.message);
        }
      catch (GLib.DBusError e3)
        {
          GLib.warning ("Problem with the D-Bus connection : %s\n", e3.message);
        }

      return ret;
    }

  private Gee.HashMap<string, string> _copy_hash_map (
      Gee.HashMap<string, string> orig)
    {
      Gee.HashMap<string, string> copy = new Gee.HashMap<string, string> ();
      foreach (var k in orig.keys)
        {
          var v = orig.get (k);
          copy.set (k.dup (), v.dup ());
        }
      return copy;
    }

  private void _setup_connection () throws BackendSetupError
    {
      try
        {
          this._connection = Tracker.Sparql.Connection.get ();
        }
      catch (GLib.IOError e1)
        {
          throw new BackendSetupError.ADD_CONTACT_FAILED
          ("Could not connect to D-Bus service : %s\n", e1.message);
        }
      catch (Tracker.Sparql.Error e2)
        {
          throw new BackendSetupError.ADD_CONTACT_FAILED
          ("Error fetching SPARQL connection handler : %s\n", e2.message);
        }
      catch (GLib.DBusError e3)
        {
          throw new BackendSetupError.ADD_CONTACT_FAILED
          ("Error fetching SPARQL connection handler : %s\n", e3.message);
        }
      catch (GLib.SpawnError e4)
        {
          throw new BackendSetupError.ADD_CONTACT_FAILED
          ("Error fetching SPARQL connection handler : %s\n", e4.message);
        }
    }

  private void _add_contacts () throws BackendSetupError
    {
      string query = "";

      this._contacts.reverse ();
      foreach (var c in this._contacts)
        {
          query = query + "\n" + this._get_insert_query (c);
        }

      try
        {
          this._connection.update (query);
        }
      catch (Tracker.Sparql.Error e1)
        {
          throw new BackendSetupError.ADD_CONTACT_FAILED
          ("Problem getting connection : %s\n", e1.message);
        }
      catch (GLib.IOError e2)
        {
          throw new BackendSetupError.ADD_CONTACT_FAILED
          ("Error fetching SPARQL connection handler : %s\n", e2.message);
        }
      catch (GLib.DBusError e3)
        {
          throw new BackendSetupError.ADD_CONTACT_FAILED
          ("Could not connect to D-Bus service : %s\n", e3.message);
        }
    }

  private string _get_insert_query (Gee.HashMap<string, string> contact)
    {
      const string q_photo_uri_t = " . <%s> a nfo:Image, " +
          "nie:DataObject ; nie:url '%s' ; nie:title '%s' ";
      const string im_addr_t = " . <%s> a nco:IMAddress, " +
          "nie:InformationElement; nco:imProtocol " +
          "'%s' ; nco:imID '%s';   " +
          "nco:imNickname '%s'; " +
          "nco:imPresence nco:presence-status-available " +
          " . <%smyimaccount> a nco:IMAccount; " +
          "nco:imDisplayName '%s'; nco:hasIMContact " +
          "<%s>  ";
      const string affl_t = " . <%smyaffiliation> a nco:Affiliation " +
          " . <%smyaffiliation> nco:hasIMAddress " +
          " <%s>  ";
      const string af_t = " . <affl:001> a nco:Affiliation; " +
          "nco:title '%s'; nco:department '%s'; nco:role '%s' ";
      const string postal_t = " . <affl:001> a nco:Affiliation ; " +
          "nco:hasPostalAddress <postal:001> . " +
          " <postal:001> a nco:PostalAddress ; " +
          "nco:pobox '%s'; " +
          "nco:district '%s'; " +
          "nco:county '%s'; " +
          "nco:locality '%s'; " +
          "nco:postalcode '%s'; " +
          "nco:streetAddress '%s'; " +
          "nco:addressLocation '%s'; " +
          "nco:extendedAddress '%s'; " +
          "nco:country '%s'; " +
          "nco:region '%s' ";

      string urn_contact;
      if (contact.unset (TrackerTest.Backend.URN, out urn_contact) == false)
        {
          urn_contact = "_:x";
        }

      string photo_uri = "";
      string q = "INSERT { " + urn_contact + " a nco:PersonContact  ";
      Gee.HashMap<string, string> addresses = null;
      string[] phones = null;
      string[] emails = null;
      string[] urls = null;
      string affiliation = "";
      string postal_address = "";

      foreach (var k in contact.keys)
        {
          string v = contact.get (k);
          if (k == Trf.OntologyDefs.NCO_PHOTO)
            {
              photo_uri = v;
              v = "<" + v + ">";
            }
          else if (k == Trf.OntologyDefs.NCO_IMADDRESS)
            {
              addresses = this._parse_addrs (v);
              k = "";
              v = "";
              foreach (var addr in addresses.keys)
                {
                  string vtemp;
                  vtemp = " nco:hasAffiliation [ a nco:Affiliation ; ";
                  vtemp += "nco:hasIMAddress <" + addr + "> ] ";
                  if (v != "")
                    {
                      v += "; ";
                    }
                  v += vtemp;
                }
            }
          else if (k == Trf.OntologyDefs.NCO_PHONE_PROP)
            {
              phones = v.split (",");
              k = "";
              v = this._build_relation (Trf.OntologyDefs.NCO_HAS_AFFILIATION,
                  phones);
            }
          else if (k == Trf.OntologyDefs.NCO_EMAIL_PROP)
            {
              emails = v.split (",");
              k = "";
              v = this._build_relation (Trf.OntologyDefs.NCO_HAS_AFFILIATION,
                  emails);
            }
          else if (k == TrackerTest.Backend.URLS)
            {
              urls = v.split (",");
              k = "";
              v = this._build_relation (Trf.OntologyDefs.NCO_HAS_AFFILIATION,
                  urls);
            }
          else if (k == Trf.OntologyDefs.NAO_TAG)
            {
              v = Trf.OntologyDefs.NAO_FAVORITE;
            }
          else if (k == Trf.OntologyDefs.NCO_HAS_AFFILIATION)
            {
              affiliation = v;
              v = "<affl:001>";
            }
          else  if (k == Trf.OntologyDefs.NCO_GENDER)
            {

            }
          else  if (k == Trf.OntologyDefs.NCO_POSTAL_ADDRESS)
            {
              postal_address = v;
              k = Trf.OntologyDefs.NCO_HAS_AFFILIATION;
              v = "<affl:001>";
            }
          else
            {
              v = "'" + v + "'";
            }

          q += "; ";
          string s = k + " " + v;
          q += s;
        }

      if (photo_uri != "")
        {
          q += q_photo_uri_t.printf (photo_uri, photo_uri, photo_uri);
        }

      if (addresses != null && addresses.size > 0)
        {
          foreach (var addr in addresses.keys)
            {
              string proto = addresses.get (addr);
              string q1 = im_addr_t.printf (addr, proto, addr, addr, addr,
                  addr, addr);

              string q2 = affl_t.printf (addr, addr, addr);

              q += "%s%s".printf (q1, q2);
            }
        }

      if (phones != null && phones.length > 0)
        {
          foreach (var p in phones)
            {
              var phone_urn = "<phone:%s>".printf (p);
              var affl = "<%s>".printf (p);
              this.insert_triplet (phone_urn, "a", Trf.OntologyDefs.NCO_PHONE,
                  Trf.OntologyDefs.NCO_PHONE_PROP, p);
              this.insert_triplet (affl, "a", Trf.OntologyDefs.NCO_AFFILIATION);
              this.insert_triplet (affl,
                  Trf.OntologyDefs.NCO_HAS_PHONE, phone_urn);
            }
        }

      if (emails != null && emails.length > 0)
        {
          foreach (var p in emails)
            {
              var email_urn = "<email:%s>".printf (p);
              var affl = "<%s>".printf (p);
              this.insert_triplet (email_urn, "a", Trf.OntologyDefs.NCO_EMAIL,
                  Trf.OntologyDefs.NCO_EMAIL_PROP, p);
              this.insert_triplet (affl, "a", Trf.OntologyDefs.NCO_AFFILIATION);
              this.insert_triplet (affl,
                  Trf.OntologyDefs.NCO_HAS_EMAIL, email_urn);
            }
        }

      if (urls != null && urls.length > 0)
        {
          int i = 0;
          foreach (var p in urls)
            {
              string website_type = "";
              var affl = "<%s>".printf (p);
              switch (i % 3)
                {
                  case 0:
                    website_type = Trf.OntologyDefs.NCO_WEBSITE;
                    break;
                  case 1:
                    website_type = Trf.OntologyDefs.NCO_BLOG;
                    break;
                  case 2:
                    website_type = "nco:url";
                    break;
                }

              this.insert_triplet (affl, "a", Trf.OntologyDefs.NCO_AFFILIATION,
                  website_type, p);
              i++;
            }
        }

      if (affiliation != "")
        {
          string[] role_info = affiliation.split (",");
          q += af_t.printf (role_info[0], role_info[1], role_info[2]);
        }

      if (postal_address != "")
        {
          string[] postal_info = postal_address.split (":");
          q += postal_t.printf (postal_info[0], postal_info[1],
               postal_info[2], postal_info[3], postal_info[4],
               postal_info[5], postal_info[6], postal_info[7],
               postal_info[8], postal_info[9]);
        }

      q += " . }";

      if (this.debug)
        {
          GLib.stdout.printf ("_get_insert_query : %s\n", q);
        }

      return q;
    }

  private Gee.HashMap<string, string> _parse_addrs (string addr_s)
    {
      Gee.HashMap<string, string> ret = new Gee.HashMap<string, string> ();
      string[] im_addrs = addr_s.split (",");

      foreach (var a in im_addrs)
        {
          string[] info = a.split ("#");
          string proto = info[0];
          string addr = info[1];

          ret.set ((owned) addr, (owned) proto);
        }

      return ret;
    }

  private string _build_relation (string predicate, string[] objects)
    {
      string ret = "";

      foreach (var obj in objects)
        {
          string vtemp1;
          vtemp1 = " " + predicate + " <" + obj + "> ";
          if (ret != "")
            {
              ret += "; ";
            }
          ret += vtemp1;
        }

      return ret;
    }
}
