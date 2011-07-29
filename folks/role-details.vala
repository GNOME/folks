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
using GLib;

/**
 * This interface represents the role a {@link Persona} and {@link Individual}
 * have in a given Organisation.
 *
 * @since 0.4.0
 */
public class Folks.Role : Object
{
  /**
   * The name of the organisation in which the role is held.
   */
  public string organisation_name { get; set; }

  /**
   * The name of the position held.
   */
  public string title { get; set; }

  /**
   * The UID that distinguishes this role.
   */
  public string uid { get; set; }

  /**
   * Default constructor.
   *
   * @param title title of the position
   * @param organisation_name organisation where the role is hold
   * @param uid a Unique ID associated to this Role
   * @return a new Role
   *
   * @since 0.4.0
   */
  public Role (string? title = null,
      string? organisation_name = null, string? uid = null)
    {
      if (title == null)
        {
          title = "";
        }

      if (organisation_name == null)
        {
          organisation_name = "";
        }

      if (uid == null)
        {
          uid = "";
        }

      Object (uid:                  uid,
              title:                title,
              organisation_name:    organisation_name);
    }

  /**
   * Compare if two roles are equal. Roles are equal if their titles and
   * organisation names are equal.
   *
   * @param a a role to compare
   * @param b another role to compare
   * @return `true` if the roles are equal, `false` otherwise
   */
  public static bool equal (Role a, Role b)
    {
      return (a.title == b.title) &&
          (a.organisation_name == b.organisation_name);
    }

  /**
   * Hash function for the class. Suitable for use as a hash table key.
   *
   * @param r a role to hash
   * @return hash value for the role instance
   */
  public static uint hash (Role r)
    {
      return r.organisation_name.hash () + r.title.hash ();
    }

  /**
   * Formatted version of this role.
   *
   * @since 0.4.0
   */
  public string to_string ()
    {
      var str = _("Title: %s , Organisation: %s");
      return str.printf (this.title, this.organisation_name);
    }
}

/**
 * This interfaces represents the list of roles a {@link Persona} and
 * {@link Individual} might have.
 *
 * @since 0.4.0
 */
public interface Folks.RoleDetails : Object
{
  /**
   * The roles of the contact.
   *
   * @since 0.5.1
   */
  public abstract Set<Role> roles { get; set; }
}
