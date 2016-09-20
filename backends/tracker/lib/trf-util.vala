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
 *       Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 */


using Gee;
using Tracker;
using Tracker.Sparql;

public struct Event
{
  int graph_id;
  int subject_id;
  int pred_id;
  int object_id;
}

[DBus (name = "org.freedesktop.Tracker1.Resources")]
private interface Resources : DBusProxy {
  [DBus (name = "GraphUpdated")]
  public signal void graph_updated
      (string class_name, Event[] deletes, Event[] inserts);
}

internal class Trf.AfflInfo : Object
{
  public string im_tracker_id { get; set; }

  public string im_proto { get; set; }

  public string im_account_id { get; set; }

  public string im_nickname { get; set; }

  public string affl_tracker_id  { get; set; }

  public string title { get; set; }

  public string org  { get; set; }

  public string role { get; set; }

  public Folks.PostalAddressFieldDetails postal_address_fd;

  public string email { get; set; }

  public string phone  { get; set; }

  public string website  { get; set; }

  public string blog  { get; set; }

  public string url  { get; set; }

  public string to_string ()
    {
      string ret = " { ";
      bool first = true;
      var properties = this.get_class ().list_properties ();

      foreach (unowned ParamSpec pspec in properties)
        {
          var property = pspec.get_name ();
          var prop_value = Value (pspec.value_type);
          this.get_property (property, ref prop_value);
          string value = prop_value.get_string ();

          if (first == false)
            ret += ", ";

          ret += "%s : %s".printf (property, value);
          first = false;
       }

      ret += " } ";

      return ret;
    }
}

public class Trf.OntologyDefs : Object
{
  public const string DEFAULT_CONTACT_URN =
  "http://www.semanticdesktop.org/ontologies/2007/03/22/nco#default-contact-me";
  public const string PERSON_CLASS =
  "http://www.semanticdesktop.org/ontologies/2007/03/22/nco#PersonContact";
  public const string NCO_FULLNAME = "nco:fullname";
  public const string NCO_FAMILY = "nco:nameFamily";
  public const string NCO_GIVEN = "nco:nameGiven";
  public const string NCO_ADDITIONAL = "nco:nameAdditional";
  public const string NCO_SUFFIX = "nco:nameHonorificSuffix";
  public const string NCO_PREFIX = "nco:nameHonorificPrefix";
  public const string NCO_NICKNAME = "nco:nickname";
  public const string RDF_TYPE = "ns:type";
  public const string NCO_PERSON = "nco:PersonContact";
  public const string NCO_URL = "nco:url";
  public const string NCO_WEBSITE = "nco:websiteUrl";
  public const string NCO_BLOG = "nco:blogUrl";
  public const string NAO_FAVORITE = "nao:predefined-tag-favorite";
  public const string NAO_TAG = "nao:hasTag";
  public const string NAO_PROPERTY = "nao:Property";
  public const string NAO_HAS_PROPERTY = "nao:hasProperty";
  public const string NAO_PROPERTY_NAME = "nao:propertyName";
  public const string NAO_PROPERTY_VALUE = "nao:propertyValue";
  public const string NCO_HAS_EMAIL = "nco:hasEmailAddress";
  public const string NCO_EMAIL = "nco:EmailAddress";
  public const string NCO_EMAIL_PROP = "nco:emailAddress";
  public const string NCO_HAS_PHONE = "nco:hasPhoneNumber";
  public const string NCO_PHONE = "nco:PhoneNumber";
  public const string NCO_PHONE_PROP = "nco:phoneNumber";
  public const string NCO_HAS_AFFILIATION = "nco:hasAffiliation";
  public const string NCO_AFFILIATION = "nco:Affiliation";
  public const string NCO_BIRTHDAY = "nco:birthDate";
  public const string NCO_NOTE = "nco:note";
  public const string NCO_GENDER = "nco:gender";
  public const string NCO_MALE = "nco:gender-male";
  public const string NCO_FEMALE = "nco:gender-female";
  public const string NCO_PHOTO = "nco:photo";
  public const string NIE_URL = "nie:url";
  public const string NFO_IMAGE = "nfo:Image";
  public const string NIE_DATAOBJECT = "nie:DataObject";
  public const string NCO_IMADDRESS = "nco:IMAddress";
  public const string NCO_HAS_IMADDRESS = "nco:hasIMAddress";
  public const string NCO_IMPROTOCOL = "nco:imProtocol";
  public const string NCO_IMID = "nco:imID";
  public const string NCO_IM_NICKNAME = "nco:imNickname";
  public const string NCO_POSTAL_ADDRESS = "nco:PostalAddress";
  public const string NCO_HAS_POSTAL_ADDRESS = "nco:hasPostalAddress";
  public const string NCO_POBOX = "nco:pobox";
  public const string NCO_DISTRICT = "nco:district";
  public const string NCO_COUNTY = "nco:county";
  public const string NCO_LOCALITY = "nco:locality";
  public const string NCO_POSTALCODE = "nco:postalcode";
  public const string NCO_STREET_ADDRESS = "nco:streetAddress";
  public const string NCO_ADDRESS_LOCATION = "nco:addressLocation";
  public const string NCO_EXTENDED_ADDRESS = "nco:extendedAddress";
  public const string NCO_COUNTRY = "nco:country";
  public const string NCO_REGION = "nco:region";
  public const string NCO_ROLE = "nco:role";
  public const string NCO_TITLE = "nco:title";
  public const string NCO_ORG = "nco:org";
  public const string NCO_URL_PREFIX =
      "<http://www.semanticdesktop.org/ontologies/2007/03/22/";
  public const string NAO_URL_PREFIX =
      "<http://www.semanticdesktop.org/ontologies/2007/08/15/";
  public const string RDF_URL_PREFIX =
      "<http://www.w3.org/1999/02/";
}
