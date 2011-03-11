/*
 * Copyright (C) 2010 Collabora Ltd.
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
 *       Marco Barisione <marco.barisione@collabora.co.uk>
 *       Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 */

using GLib;

/**
 * Object representing a postal mail address.
 * The components of the address are never null, an empty string
 * indicates that a property is not set.
 */
public class Folks.PostalAddress : Object
{
  private string _po_box = "";
  /**
   * The PO Box.
   *
   * The PO Box (also known as Postal office box or Postal box).
   */
  public string po_box
    {
      get { return _po_box; }
      construct set { _po_box = (value != null ? value : ""); }
    }

  private string _extension = "";
  /**
   * The address extension.
   *
   * Any additional part of the address, for instance a flat number.
   */
  public string extension
    {
      get { return _extension; }
      construct set { _extension = (value != null ? value : ""); }
    }

  private string _street = "";
  /**
   * The street name and number.
   *
   * The street name including the optional building number.
   * The number can be before or after the street name based on the
   * language and country.
   */
  public string street
    {
      get { return _street; }
      construct set { _street = (value != null ? value : ""); }
    }

  private string _locality = "";
  /**
   * The locality.
   *
   * The locality, for instance the city name.
   */
  public string locality
    {
      get { return _locality; }
      construct set { _locality = (value != null ? value : ""); }
    }

  private string _region = "";
  /**
   * The region.
   *
   * The region, for instance the name of the state or province.
   */
  public string region
    {
      get { return _region; }
      construct set { _region = (value != null ? value : ""); }
    }

  private string _postal_code = "";
  /**
   * The postal code.
   *
   * The postal code (also known as post code, postcode or ZIP code).
   */
  public string postal_code
    {
      get { return _postal_code; }
      construct set { _postal_code = (value != null ? value : ""); }
    }

  private string _country = "";
  /**
   * The country.
   *
   * The name of the country.
   */
  public string country
    {
      get { return _country; }
      construct set { _country = (value != null ? value : ""); }
    }

  private string _address_format = "";
  /**
   * The address format.
   *
   * The two letter country code that determines the format or exact
   * meaning of the other fields.
   */
  public string address_format
    {
      get { return _address_format; }
      construct set { _address_format = (value != null ? value : ""); }
    }

  private List<string> _types;
  /**
   * The types of the address.
   *
   * The types of address, for instance an address can be a home or work
   * address.
   */
  public List<string> types
    {
      get { return this._types; }
      construct set
        {
          this._types = new List<string> ();
          foreach (unowned string type in value)
            this._types.prepend (type);
          this._types.reverse ();
        }
    }

  private string _uid = "";
  /**
   * The UID of the Postal Address (if any).
   */
  public string uid
    {
      get { return _uid; }
      construct set { _uid = (value != null ? value : ""); }
    }

  /**
   * Create a PostalAddress.
   *
   * You can pass `null` if a component is not set.
   *
   * @param po_box the PO Box
   * @param extension the address extension
   * @param street the street name and number
   * @param locality the locality (city, town or village) name
   * @param region the region (state or province) name
   * @param postal_code the postal code
   * @param address_format the address format
   */
  public PostalAddress (string? po_box, string? extension, string? street,
      string? locality, string? region, string? postal_code, string? country,
      string? address_format, List<string> types, string? uid)
    {
      Object (po_box:         po_box,
              extension:      extension,
              street:         street,
              locality:       locality,
              region:         region,
              postal_code:    postal_code,
              country:        country,
              address_format: address_format,
              types:          types,
              uid:            uid);
    }

  public bool equal (PostalAddress with)
    {
      if (this.po_box != with.po_box ||
          this.extension != with.extension ||
          this.street != with.street ||
          this.locality != with.locality ||
          this.region != with.region ||
          this.postal_code != with.postal_code ||
          this.country != with.country ||
          this.address_format != with.address_format ||
          this.types.length () != with.types.length () ||
          this.uid != with.uid)
        return false;

      for (int i=0; i<this.types.length (); i++)
        {
          if (this.types.nth_data (i) != with.types.nth_data (i))
            return false;
        }

      return true;
    }

  /*
   * Returns a formatted address.
   *
   * @since 0.3.UNRELEASED
   */
  public string to_string ()
    {
      var str = _("%s, %s, %s, %s, %s, %s, %s");
      return str.printf (this.po_box, this.extension, this.street,
          this.locality, this.region, this.postal_code, this.country);
    }
}

/**
 * Interface for classes that can provide postal addresses, such as
 * {@link Persona} and {@link Individual}.
 */
public interface Folks.PostalAddressDetails : Object
{
  /**
   * The postal addresses of the contact.
   *
   * A list of postal addresses associated to the contact.
   */
  public abstract List<PostalAddress> postal_addresses { get; set; }
}
