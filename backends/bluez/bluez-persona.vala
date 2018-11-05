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

  private SmallSet<UrlFieldDetails>? _urls = null;
  private Set<UrlFieldDetails> _urls_ro;

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

  private LoadableIcon? _avatar = null;

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

  private SmallSet<PhoneFieldDetails>? _phone_numbers = null;
  private Set<PhoneFieldDetails> _phone_numbers_ro;

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

  private StructuredName? _structured_name = null;

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

  private string _full_name = "";

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

  private string _nickname = "";

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

  private SmallSet<EmailFieldDetails>? _email_addresses = null;
  private Set<EmailFieldDetails> _email_addresses_ro;

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

      this._phone_numbers = new SmallSet<PhoneFieldDetails> (
           AbstractFieldDetails<string>.hash_static,
           AbstractFieldDetails<string>.equal_static);
      this._phone_numbers_ro = this._phone_numbers.read_only_view;
      this._email_addresses = new SmallSet<EmailFieldDetails> (
           AbstractFieldDetails<string>.hash_static,
           AbstractFieldDetails<string>.equal_static);
      this._email_addresses_ro = this._email_addresses.read_only_view;
      this._urls = new SmallSet<UrlFieldDetails> (
           AbstractFieldDetails<string>.hash_static,
           AbstractFieldDetails<string>.equal_static);
      this._urls_ro = this._urls.read_only_view;
    }

  private void _update_params (AbstractFieldDetails details,
      E.VCardAttribute attr)
    {
      foreach (unowned E.VCardAttributeParam param in attr.get_params ())
        {
          /* EVCard handles parameter names and values entirely
           * case-insensitively, so we’ll do the same. */
          foreach (unowned string param_value in param.get_values ())
            {
              details.add_parameter (param.get_name ().down (),
                  param_value.down ());
            }
        }
    }

  /**
   * Update the Persona’s properties from a vCard.
   *
   * Parse the given ``vcard`` and set the persona’s properties from it. This
   * emits property change notifications as appropriate.
   *
   * @param vcard pre-parsed vCard
   * @return ``true`` if any properties were changed, ``false`` otherwise
   *
   * @since 0.9.7
   */
  internal bool update_from_vcard (E.VCard card)
    {
      var properties_changed = false;

      /* Somewhere to store the new property values. */
      var new_phone_numbers = new SmallSet<PhoneFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);
      var new_uris = new SmallSet<UrlFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);
      var new_email_addresses = new SmallSet<EmailFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);
      BytesIcon? new_avatar = null;
      var new_full_name = "";
      var new_nickname = "";
      StructuredName? new_structured_name = null;

      /* Parse the attributes by iterating over the vCard’s attribute list once
       * only. Convenience functions like E.VCard.get_attribute() cause multiple
       * iterations over the list. */
      unowned GLib.List<E.VCardAttribute> attrs =
          card.get_attributes ();

      foreach (var attr in attrs)
        {
          unowned string attr_name = attr.get_name ();

          if (attr_name == "TEL")
            {
              var val = attr.get_value ();
              if (val == null || (!) val == "")
                  continue;

              var new_field_details = new PhoneFieldDetails ((!) val);
              this._update_params (new_field_details, attr);
              new_phone_numbers.add (new_field_details);
            }
          else if (attr_name == "URL")
            {
              var val = attr.get_value ();
              if (val == null || (!) val == "")
                  continue;

              var new_field_details = new UrlFieldDetails ((!) val);
              this._update_params (new_field_details, attr);
              new_uris.add (new_field_details);
            }
          else if (attr_name == "EMAIL")
            {
              var val = attr.get_value ();
              if (val == null || (!) val == "")
                  continue;

              var new_field_details = new EmailFieldDetails ((!) val);
              this._update_params (new_field_details, attr);
              new_email_addresses.add (new_field_details);
            }
          else if (attr_name == "PHOTO")
            {
              var encoded_data = (string) attr.get_value ().data;
              var bytes = new Bytes (Base64.decode (encoded_data));
              new_avatar = new BytesIcon (bytes);
            }
          else if (attr_name == "FN")
              new_full_name = attr.get_value ();
          else if (attr_name == "NICKNAME")
              new_nickname = attr.get_value ();
          else if (attr_name == "N")
            {
              unowned GLib.List<string> values = attr.get_values ();
              unowned string? family_name = null, given_name = null,
                  additional_names = null, prefixes = null, suffixes = null;

              if (values != null)
                {
                  family_name = values.data;
                  values = values.next;
                }
              if (values != null)
                {
                  given_name = values.data;
                  values = values.next;
                }
              if (values != null)
                {
                  additional_names = values.data;
                  values = values.next;
                }
              if (values != null)
                {
                  prefixes = values.data;
                  values = values.next;
                }
              if (values != null)
                {
                  suffixes = values.data;
                  values = values.next;
                }

              if (suffixes == null || values != null)
                {
                  debug ("Expected 5 components in N attribute of vCard, " +
                      "but got %s.", (suffixes == null) ? "fewer" : "more");
                }

              new_structured_name =
                  new StructuredName (family_name, given_name, additional_names,
                      prefixes, suffixes);
            }
          else if (attr_name != "VERSION" && attr_name != "UID")
            {
              /* Unknown attribute. */
              warning ("Unknown attribute ‘%s’ in vCard for persona %s.",
                  attr_name, this.uid);
            }
        }

      /* Now test the new property values to see if they’ve changed; if so, emit
       * property change notifications. */
      this.freeze_notify ();

      /* Phone numbers. */
      if (!Utils.set_string_afd_equal (this._phone_numbers,
              new_phone_numbers))
        {
          this._phone_numbers = new_phone_numbers;
          this._phone_numbers_ro = new_phone_numbers.read_only_view;
          this.notify_property ("phone-numbers");
          properties_changed = true;
        }

      /* URIs. */
      if (!Folks.Internal.equal_sets<UrlFieldDetails> (this._urls, new_uris))
        {
          this._urls = new_uris;
          this._urls_ro = new_uris.read_only_view;
          this.notify_property ("urls");
          properties_changed = true;
        }

      /* E-mail addresses. */
      if (!Folks.Internal.equal_sets<EmailFieldDetails> (this._email_addresses,
              new_email_addresses))
        {
          this._email_addresses = new_email_addresses;
          this._email_addresses_ro = new_email_addresses.read_only_view;
          this.notify_property ("email-addresses");
          properties_changed = true;
        }

      /* Photo. */
      if ((new_avatar == null) != (this._avatar == null) ||
          (new_avatar != null && this._avatar != null &&
           !new_avatar.equal (this._avatar)))
        {
          this._avatar = new_avatar;
          this.notify_property ("avatar");
          properties_changed = true;
        }

      /* Full name. */
      if (this._full_name != new_full_name)
        {
          this._full_name = new_full_name;
          this.notify_property ("full-name");
          properties_changed = true;
        }

      /* Nickname. */
      if (this._nickname != new_nickname)
        {
          this._nickname = new_nickname;
          this.notify_property ("nickname");
          properties_changed = true;
        }

      /* Structured name. */
      if ((new_structured_name == null) != (this._structured_name == null) ||
          (new_structured_name != null && this._structured_name != null &&
           !new_structured_name.equal (this._structured_name)))
        {
          this._structured_name = new_structured_name;
          this.notify_property ("structured-name");
          properties_changed = true;
        }

      this.thaw_notify ();

      return properties_changed;
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
