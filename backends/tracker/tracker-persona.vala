/*
 * Copyright 2023 Collabora Ltd.
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
 *       Corentin Noël <corentin.noel@collabora.com>
 */

using GLib;
using Gee;
using Folks;

/**
 * A persona subclass which represents a single persona from a simple key file.
 *
 * @since 0.9.6
 */
public class Folks.Backends.TrackerPersona : Folks.Persona,
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
      get { return TrackerPersona._linkable_properties; }
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
      get { return TrackerPersona._writeable_properties; }
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
  private Tracker.Sparql.Connection sparql_connection;

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
  public TrackerPersona (Tracker.Sparql.Connection sparql_connection, Folks.PersonaStore store, string urn, string uid, string fullname)
    {
        Object(iid: urn, uid: uid, full_name: fullname, store: store);
        this.sparql_connection = sparql_connection;
    }

  construct
    {
      debug ("Adding Tracker Persona '%s' (IID '%s')", this.uid, this.iid);

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
