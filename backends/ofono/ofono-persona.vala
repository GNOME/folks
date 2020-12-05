/*
 * Copyright (C) 2012 Collabora Ltd.
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
 *          Jeremy Whiting <jeremy.whiting@collabora.co.uk>
 *
 * Based on kf-persona.vala by:
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;
using Gee;
using Folks;
using Folks.Backends.Ofono;

/**
 * A persona subclass which represents a single persona from a simple key file.
 *
 * @since 0.9.0
 */
public class Folks.Backends.Ofono.Persona : Folks.Persona,
    EmailDetails,
    NameDetails,
    PhoneDetails
{
  private StructuredName? _structured_name = null;
  private string _full_name = "";
  private string _nickname = "";
  private SmallSet<PhoneFieldDetails> _phone_numbers;
  private Set<PhoneFieldDetails> _phone_numbers_ro;
  private SmallSet<EmailFieldDetails> _email_addresses;
  private Set<EmailFieldDetails> _email_addresses_ro;

  private const string[] _linkable_properties =
    {
      "phone-numbers",
      "email-addresses",
      null /* FIXME: https://bugzilla.gnome.org/show_bug.cgi?id=682698 */
    };
  private static string[] _writeable_properties = {};

  /**
   * {@inheritDoc}
   */
  public override string[] linkable_properties
    {
      get { return Ofono.Persona._linkable_properties; }
    }

  /**
   * {@inheritDoc}
   */
  public override string[] writeable_properties
    {
      get { return Ofono.Persona._writeable_properties; }
    }

  /**
   * {@inheritDoc}
   */
  [CCode (notify = false)]
  public Set<PhoneFieldDetails> phone_numbers
    {
      get { return this._phone_numbers_ro; }
      set { this.change_phone_numbers.begin (value); } /* not writeable */
    }

  /**
   * {@inheritDoc}
   */
  [CCode (notify = false)]
  public StructuredName? structured_name
    {
      get { return this._structured_name; }
      set { this.change_structured_name.begin (value); } /* not writeable */
    }

  /**
   * {@inheritDoc}
   */
  [CCode (notify = false)]
  public string full_name
    {
      get { return this._full_name; }
      set { this.change_full_name.begin (value); } /* not writeable */
    }

  /**
   * {@inheritDoc}
   */
  [CCode (notify = false)]
  public string nickname
    {
      get { return this._nickname; }
      set { this.change_nickname.begin (value); } /* not writeable */
    }

  /**
   * {@inheritDoc}
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
   * Create a new persona for the given vCard contents.
   *
   * @param vcard the vCard data to use for this {@link Persona}.
   * @param store the {@link PersonaStore} this {@link Persona} belongs to.
   *
   * @since 0.9.0
   */
  public Persona (string vcard, Folks.PersonaStore store)
    {
      var iid = Checksum.compute_for_string (ChecksumType.SHA1, vcard);
      var uid = Folks.Persona.build_uid ("ofono", store.id, iid);

      /* Use the IID as the display ID since no other suitable identifier is
       * available which we can guarantee is unique within the store. */
      Object (display_id: iid,
              iid: iid,
              uid: uid,
              store: store,
              is_user: false);
      this._set_vcard (vcard);
    }

  construct
    {
      debug ("Adding Ofono Persona '%s' (IID '%s', group '%s')", this.uid,
          this.iid, this.display_id);

      this._phone_numbers = new SmallSet<PhoneFieldDetails> ();
      this._phone_numbers_ro = this._phone_numbers.read_only_view;

      this._email_addresses = new SmallSet<EmailFieldDetails> ();
      this._email_addresses_ro = this._email_addresses.read_only_view;
    }

  private void _set_vcard (string vcard)
    {
      E.VCard card = new E.VCard.from_string (vcard);

      E.VCardAttribute? attribute = card.get_attribute ("TEL");
      if (attribute != null)
        {
          this._phone_numbers.add (new PhoneFieldDetails (attribute.get_value_decoded ().str) );
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

      attribute = card.get_attribute ("N");
      if (attribute != null)
        {
          unowned GLib.List<StringBuilder> values = attribute.get_values_decoded ();
          if (values.length () >= 5)
            {
              this._structured_name = new StructuredName (values.nth_data (0).str,
                  values.nth_data (1).str,
                  values.nth_data (2).str,
                  values.nth_data (3).str,
                  values.nth_data (4).str);
            }
          else
            {
              warning ("Expected 5 components to N value of vcard, got %u", values.length ());
            }
        }

      attribute = card.get_attribute ("EMAIL");
      if (attribute != null)
        {
          this._email_addresses.add (new EmailFieldDetails (attribute.get_value_decoded ().str) );
        }
    }

  /**
   * {@inheritDoc}
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
