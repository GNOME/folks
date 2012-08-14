/*
 * Copyright (C) 2011 Collabora Ltd.
 * Copyright (C) 2011 Philip Withnall
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
 *       Philip Withnall <philip@tecnocode.co.uk>
 */

using GLib;

/**
 * Structured name representation for human names.
 *
 * Represents a full name split in its constituent parts (given name,
 * family name, etc.). This structure corresponds to the "N" field in
 * vCards. The parts of the name are never ``null``: an empty string
 * indicates that a property is not set.
 *
 * @since 0.3.5
 */
public class Folks.StructuredName : Object
{
  private string _family_name = "";
  /**
   * The family name.
   *
   * The family name (also known as surname or last name) of a contact.
   *
   * @since 0.3.5
   */
  public string family_name
    {
      get { return this._family_name; }
      construct set { this._family_name = value != null ? value : ""; }
    }

  private string _given_name = "";
  /**
   * The given name.
   *
   * The family name (also known as first name) of a contact.
   *
   * @since 0.3.5
   */
  public string given_name
    {
      get { return this._given_name; }
      construct set { this._given_name = value != null ? value : ""; }
    }

  private string _additional_names = "";
  /**
   * Additional names.
   *
   * The additional names of a contact, for instance the contact's
   * middle name.
   *
   * @since 0.3.5
   */
  public string additional_names
    {
      get { return this._additional_names; }
      construct set { this._additional_names = value != null ? value : ""; }
    }

  private string _prefixes = "";
  /**
   * The prefixes of a name.
   *
   * The prefixes used in front of the name (for instance "Mr", "Mrs",
   * "Doctor" or honorific titles).
   *
   * @since 0.3.5
   */
  public string prefixes
    {
      get { return this._prefixes; }
      construct set { this._prefixes = value != null ? value : ""; }
    }

  private string _suffixes = "";
  /**
   * The suffixes of a name.
   *
   * The suffixes used after a name (for instance "PhD" or "Junior").
   *
   * @since 0.3.5
   */
  public string suffixes
    {
      get { return this._suffixes; }
      construct set { this._suffixes = value != null ? value : ""; }
    }

  /**
   * Create a StructuredName.
   *
   * You can pass ``null`` if a component is not set.
   *
   * @param family_name the family (last) name
   * @param given_name the given (first) name
   * @param additional_names additional names
   * @param prefixes prefixes of the name
   * @param suffixes suffixes of the name
   * @return a new StructuredName
   *
   * @since 0.3.5
   */
  public StructuredName (string? family_name, string? given_name,
      string? additional_names, string? prefixes, string? suffixes)
    {
      Object (family_name:      family_name,
              given_name:       given_name,
              additional_names: additional_names,
              prefixes:         prefixes,
              suffixes:         suffixes);
    }

  /**
   * Create a StructuredName.
   *
   * Shorthand for the common case of just having the family and given
   * name of a contact. It's equivalent to calling
   * {@link StructuredName.StructuredName} and passing ``null`` for all
   * the other components.
   *
   * @param family_name the family (last) name
   * @param given_name the given (first) name
   * @return a new StructuredName
   *
   * @since 0.3.5
   */
  public StructuredName.simple (string? family_name, string? given_name)
    {
      Object (family_name: family_name,
              given_name:  given_name);
    }

  /**
   * Whether none of the components is set.
   *
   * @return ``true`` if all the components are the empty string, ``false``
   * otherwise.
   *
   * @since 0.3.5
   */
  public bool is_empty ()
    {
      return this._family_name      == "" &&
             this._given_name       == "" &&
             this._additional_names == "" &&
             this._prefixes         == "" &&
             this._suffixes         == "";
    }

  /**
   * Whether two StructuredNames are the same.
   *
   * @param other the other structured name to compare with
   * @return ``true`` if all the components are the same, ``false``
   * otherwise.
   *
   * @since 0.5.0
   */
  public bool equal (StructuredName other)
    {
      return this._family_name      == other.family_name &&
             this._given_name       == other.given_name &&
             this._additional_names == other.additional_names &&
             this._prefixes         == other.prefixes &&
             this._suffixes         == other.suffixes;
    }

  /**
   * Formatted version of the structured name.
   *
   * @since 0.4.0
   */
  public string to_string ()
    {
      /* Translators: format for the formatted structured name.
       * Parameters (in order) are: prefixes (for the name), given name,
       * family name, additional names and (name) suffixes */
      var str = "%s, %s, %s, %s, %s";
      return str.printf (this.prefixes,
          this.given_name,
          this.family_name,
          this.additional_names,
          this.suffixes);
    }
}

/**
 * Interface for classes which represent contacts with names, such as
 * {@link Persona} and {@link Individual}.
 *
 * @since 0.3.5
 */
public interface Folks.NameDetails : Object
{
  /**
   * The contact name split in its constituent parts.
   *
   * Note that most of the time the structured name is not set (i.e.
   * it's ``null``) or just some of the components are set.
   * The components are immutable. To get notification of changes of
   * the structured name, you just have to connect to the ``notify`` signal
   * of this property.
   *
   * @since 0.3.5
   */
  public abstract StructuredName? structured_name { get; set; }

  /**
   * Change the contact's structured name.
   *
   * It's preferred to call this rather than setting
   * {@link NameDetails.structured_name} directly, as this method gives error
   * notification and will only return once the name has been written to the
   * relevant backing store (or the operation's failed).
   *
   * @param name the structured name (``null`` to unset it)
   * @throws PropertyError if setting the structured name failed
   * @since 0.6.2
   */
  public virtual async void change_structured_name (StructuredName? name)
      throws PropertyError
    {
      /* Default implementation. */
      throw new PropertyError.NOT_WRITEABLE (
          _("Structured name is not writeable on this contact."));
    }

  /**
   * The full name of the contact.
   *
   * The full name is the name of the contact written in the way the contact
   * prefers. For instance for English names this is usually the given name
   * followed by the family name, but Chinese names are usually the family
   * name followed by the given name.
   * The full name could or could not contain additional names (like a
   * middle name), prefixes or suffixes.
   *
   * The full name must not be ``null``: the empty string represents an unset
   * full name.
   *
   * @since 0.3.5
   */
  public abstract string full_name { get; set; }

  /**
   * Change the contact's full name.
   *
   * It's preferred to call this rather than setting
   * {@link NameDetails.full_name} directly, as this method gives error
   * notification and will only return once the name has been written to the
   * relevant backing store (or the operation's failed).
   *
   * @param full_name the full name (empty string to unset it)
   * @throws PropertyError if setting the full name failed
   * @since 0.6.2
   */
  public virtual async void change_full_name (string full_name)
      throws PropertyError
    {
      /* Default implementation. */
      throw new PropertyError.NOT_WRITEABLE (
          _("Full name is not writeable on this contact."));
    }

  /**
   * The nickname of the contact.
   *
   * The nickname is the name that the contact chose for himself. This is
   * different from {@link AliasDetails.alias} as aliases can be chosen by
   * the user and not by the contacts themselves.
   *
   * Consequently, setting the nickname only makes sense in the context of an
   * address book when updating the information a contact has specified about
   * themselves.
   *
   * The nickname must not be ``null``: the empty string represents an unset
   * nickname.
   *
   * @since 0.3.5
   */
  public abstract string nickname { get; set; }

  /**
   * Change the contact's nickname.
   *
   * It's preferred to call this rather than setting
   * {@link NameDetails.nickname} directly, as this method gives error
   * notification and will only return once the name has been written to the
   * relevant backing store (or the operation's failed).
   *
   * @param nickname the nickname (empty string to unset it)
   * @throws PropertyError if setting the nickname failed
   * @since 0.6.2
   */
  public virtual async void change_nickname (string nickname)
      throws PropertyError
    {
      /* Default implementation. */
      throw new PropertyError.NOT_WRITEABLE (
          _("Nickname is not writeable on this contact."));
    }
}
