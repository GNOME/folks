/*
 * Copyright (C) 2010-2013 Collabora Ltd.
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
 *          Arun Raghavan <arun.raghavan@collabora.co.uk>
 *          Jeremy Whiting <jeremy.whiting@collabora.com>
 *          Simon McVittie <simon.mcvittie@collabora.co.uk>
 *          Matthieu Bouron <matthieu.bouron@collabora.com>
 *
 * Based on kf-persona.vala by:
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;
using Gee;
using Folks;
using Folks.Backends.BlueZ;

/**
 * A persona subclass which represents a single persona from a simple key file.
 *
 * @since 0.9.6
 */
public class Folks.Backends.BlueZ.Persona : Folks.Persona,
    AvatarDetails,
    EmailDetails,
    NameDetails,
    PhoneDetails,
    UrlDetails
{
  private StructuredName? _structured_name = null;
  private string _full_name = "";
  private string _nickname = "";
  private Set<UrlFieldDetails>? _urls = null;
  private Set<UrlFieldDetails>? _urls_ro = null;
  private LoadableIcon? _avatar = null;
  private HashSet<PhoneFieldDetails> _phone_numbers;
  private Set<PhoneFieldDetails> _phone_numbers_ro;
  private HashSet<EmailFieldDetails> _email_addresses;
  private Set<EmailFieldDetails> _email_addresses_ro;

  private const string[] _linkable_properties =
    {
      "phone-numbers",
      "email-addresses"
    };
  private static string[] _writeable_properties = { };

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override string[] linkable_properties
    {
      get { return BlueZ.Persona._linkable_properties; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  [CCode (notify = false)]
  public Set<UrlFieldDetails> urls
    {
      get { return this._urls_ro; }
      set { this.change_urls.begin (value); } /* not writeable */
    }

  /**
  * {@inheritDoc}
  *
  * @since 0.9.6
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
  * @since 0.9.6
  */
  public override string[] writeable_properties
    {
      get { return BlueZ.Persona._writeable_properties; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  [CCode (notify = false)]
  public Set<PhoneFieldDetails> phone_numbers
    {
      get { return this._phone_numbers_ro; }
      set { this.change_phone_numbers.begin (value); } /* not writeable */
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  [CCode (notify = false)]
  public StructuredName? structured_name
    {
      get { return this._structured_name; }
      set { this.change_structured_name.begin (value); } /* not writeable */
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  [CCode (notify = false)]
  public string full_name
    {
      get { return this._full_name; }
      set { this.change_full_name.begin (value); } /* not writeable */
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  [CCode (notify = false)]
  public string nickname
    {
      get { return this._nickname; }
      set { this.change_nickname.begin (value); } /* not writeable */
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  [CCode (notify = false)]
  public Set<EmailFieldDetails> email_addresses
    {
      get { return this._email_addresses_ro; }
      set { this.change_email_addresses.begin (value); } /* not writeable */
    }

  /**
   * Create a new persona.
   *
   * Create a new persona for the {@link PersonaStore} ``store``, representing
   * the Persona given by the group ``uid`` in the key file ``key_file``.
   *
   * @param vcf the VCard filename reference. For example: 0.vcf.
   * @param name the Persona the contact name or alias.
   * @param vcard the Vcard stored as a string.
   * @param store the store to which the Persona belongs.
   * @param is_user whether the Persona is the user itself or not.
   *
   * @since 0.9.6
   */
  public Persona (string vcf, string name, string vcard,
                  Folks.PersonaStore store, bool is_user)
    {
      var iid = Checksum.compute_for_string (ChecksumType.SHA1, vcard);
      var uid = Folks.Persona.build_uid ("bluez", store.id, iid);

      Object (display_id: name,
              iid: iid,
              uid: uid,
              store: store,
              is_user: is_user);

      this._set_vcard (vcard);
    }

  construct
    {
      debug ("Adding BlueZ Persona '%s' (IID '%s', group '%s')", this.uid,
          this.iid, this.display_id);

      this._phone_numbers = new HashSet<PhoneFieldDetails> ();
      this._phone_numbers_ro = this._phone_numbers.read_only_view;

      this._email_addresses = new HashSet<EmailFieldDetails> ();
      this._email_addresses_ro = this._email_addresses.read_only_view;

      this._urls = new HashSet<UrlFieldDetails> ();
      this._urls_ro = this._urls.read_only_view;
    }

  private void _set_vcard (string vcard)
    {
      E.VCard card = new E.VCard.from_string (vcard);

      E.VCardAttribute? attribute = card.get_attribute ("TEL");
      if (attribute != null)
        {
          this._phone_numbers.add (
              new PhoneFieldDetails (attribute.get_value_decoded ().str));
        }

      attribute = card.get_attribute ("FN");
      if (attribute != null)
        {
          this._full_name = attribute.get_value_decoded ().str;
        }

      attribute = card.get_attribute ("NICKNAME");
      if (attribute != null)
        {
          this._nickname = attribute.get_value_decoded ().str;
        }

      attribute = card.get_attribute ("URL");
      if (attribute != null)
        {
          var url = attribute.get_value_decoded ().str;
          this._urls.add (new UrlFieldDetails (url));
        }

      attribute = card.get_attribute ("PHOTO");
      if (attribute != null)
        {
          var encoded_data = (string) attribute.get_value ().data;
          var bytes = new Bytes (Base64.decode (encoded_data));
          this._avatar = new BytesIcon (bytes);
        }

      attribute = card.get_attribute ("N");
      if (attribute != null)
        {
          string[] components = {"", "", "", "", ""};
          uint components_size = 5;
          unowned GLib.List<StringBuilder> values =
              attribute.get_values_decoded ();

          if (values.length () < components_size)
            components_size = values.length ();

          for (int i = 0; i < components_size; i++)
            {
              components[i] = values.nth_data (i).str;
            }

          this._structured_name = new StructuredName (components[0],
              components[1], components[2], components[3], components[4]);

          if (values.length () != 5)
            {
              debug ("Expected 5 components to N value of vcard, got %u",
                  values.length ());
            }
        }

      attribute = card.get_attribute ("EMAIL");
      if (attribute != null)
        {
          this._email_addresses.add (
              new EmailFieldDetails (attribute.get_value_decoded ().str));
        }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override void linkable_property_to_links (string prop_name,
      Folks.Persona.LinkablePropertyCallback callback)
    {
      if (prop_name == "phone-numbers")
        {
          foreach (var phone_number in this._phone_numbers)
            {
                if (phone_number.value != null)
                    callback (phone_number.value);
            }
        }
      else if (prop_name == "email-addresses")
        {
          foreach (var email_address in this._email_addresses)
            {
                if (email_address.value != null)
                    callback (email_address.value);
            }
        }
      else
        {
          /* Chain up */
          base.linkable_property_to_links (prop_name, callback);
        }
    }
}
