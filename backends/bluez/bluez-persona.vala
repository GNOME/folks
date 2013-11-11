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
   * the Persona in the given ``vcard``.
   *
   * @param vcard the vCard stored as a string
   * @param card a parsed version of the vCard
   * @param store the store to which the Persona belongs.
   * @param is_user whether the Persona is the user itself or not.
   * @param iid pre-calculated IID for the persona
   *
   * @since 0.9.6
   */
  public Persona (string vcard, E.VCard card, Folks.PersonaStore store,
      bool is_user, string iid)
    {
      var uid = Folks.Persona.build_uid ("bluez", store.id, iid);

      /* Have to use the IID as the display ID, since PBAP vCards provide no
       * other useful human-readable and unique IDs. */
      Object (display_id: iid,
              iid: iid,
              uid: uid,
              store: store,
              is_user: is_user);

      this.update_from_vcard (card);
    }

  construct
    {
      debug ("Adding BlueZ Persona '%s' (IID '%s')", this.uid, this.iid);

      this._phone_numbers = new HashSet<PhoneFieldDetails> ();
      this._phone_numbers_ro = this._phone_numbers.read_only_view;

      this._email_addresses = new HashSet<EmailFieldDetails> ();
      this._email_addresses_ro = this._email_addresses.read_only_view;

      this._urls = new HashSet<UrlFieldDetails> ();
      this._urls_ro = this._urls.read_only_view;
    }

  /**
   * Update the Persona’s properties from a vCard.
   *
   * Parse the given ``vcard`` and set the persona’s properties from it. This
   * emits property change notifications as appropriate.
   *
   * @param vcard pre-parsed vCard
   *
   * @since UNRELEASED
   */
  internal void update_from_vcard (E.VCard card)
    {
      this.freeze_notify ();

      /* Phone numbers. */
      var attribute = card.get_attribute ("TEL");
      var new_phone_numbers = new HashSet<PhoneFieldDetails> ();

      if (attribute != null)
        {
          unowned GLib.List<unowned StringBuilder> vals =
              attribute.get_values_decoded ();
          foreach (unowned StringBuilder v in vals)
              new_phone_numbers.add (new PhoneFieldDetails (v.str));
        }

      if (!Folks.Internal.equal_sets<PhoneFieldDetails> (this._phone_numbers,
              new_phone_numbers))
        {
          this._phone_numbers = new_phone_numbers;
          this._phone_numbers_ro = new_phone_numbers.read_only_view;
          this.notify_property ("phone-numbers");
        }

      /* Full name. */
      attribute = card.get_attribute ("FN");
      var new_full_name = "";

      if (attribute != null)
          new_full_name = attribute.get_value_decoded ().str;

      if (this._full_name != new_full_name)
        {
          this._full_name = new_full_name;
          this.notify_property ("full-name");
        }

      /* Nickname. */
      attribute = card.get_attribute ("NICKNAME");
      var new_nickname = "";

      if (attribute != null)
          new_nickname = attribute.get_value_decoded ().str;

      if (this._nickname != new_nickname)
        {
          this._nickname = new_nickname;
          this.notify_property ("nickname");
        }

      /* URIs. */
      attribute = card.get_attribute ("URL");
      var new_uris = new HashSet<UrlFieldDetails> ();

      if (attribute != null)
        {
          unowned GLib.List<unowned StringBuilder> vals =
              attribute.get_values_decoded ();
          foreach (unowned StringBuilder v in vals)
              new_uris.add (new UrlFieldDetails (v.str));
        }

      if (!Folks.Internal.equal_sets<UrlFieldDetails> (this._urls, new_uris))
        {
          this._urls = new_uris;
          this._urls_ro = new_uris.read_only_view;
          this.notify_property ("urls");
        }

      /* Structured name. */
      attribute = card.get_attribute ("N");
      StructuredName? new_structured_name = null;

      if (attribute != null)
        {
          string[] components = { "", "", "", "", "" };
          unowned GLib.List<unowned StringBuilder> values =
              attribute.get_values_decoded ();

          uint i = 0;
          foreach (unowned StringBuilder b in values)
            {
              if (i >= components.length)
                  break;

              components[i++] = b.str;
            }

          this._structured_name = new StructuredName (components[0],
              components[1], components[2], components[3], components[4]);

          if (i != 5)
            {
              debug ("Expected 5 components in N value of vCard, but got %u.",
                  i);
            }
        }

      if ((new_structured_name == null) != (this._structured_name == null) ||
          (new_structured_name != null && this._structured_name != null &&
           !new_structured_name.equal (this._structured_name)))
        {
          this._structured_name = new_structured_name;
          this.notify_property ("structured-name");
        }

      /* E-mail addresses. */
      attribute = card.get_attribute ("EMAIL");
      var new_email_addresses = new HashSet<EmailFieldDetails> ();

      if (attribute != null)
        {
          unowned GLib.List<unowned StringBuilder> vals =
              attribute.get_values_decoded ();
          foreach (unowned StringBuilder v in vals)
              new_email_addresses.add (new EmailFieldDetails (v.str));
        }

      if (!Folks.Internal.equal_sets<EmailFieldDetails> (this._email_addresses,
              new_email_addresses))
        {
          this._email_addresses = new_email_addresses;
          this._email_addresses_ro = new_email_addresses.read_only_view;
          this.notify_property ("email-addresses");
        }

      /* Photo. */
      attribute = card.get_attribute ("PHOTO");
      BytesIcon? new_avatar = null;

      if (attribute != null)
        {
          var encoded_data = (string) attribute.get_value ().data;
          var bytes = new Bytes (Base64.decode (encoded_data));
          new_avatar = new BytesIcon (bytes);
        }

      if ((new_avatar == null) != (this._avatar == null) ||
          (new_avatar != null && this._avatar != null &&
           !new_avatar.equal (this._avatar)))
        {
          this._avatar = new_avatar;
          this.notify_property ("avatar");
        }

      this.thaw_notify ();
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
