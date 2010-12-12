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
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;

/**
 * IM addresses exposed by an object implementing {@link HasPresence}.
 *
 * @since 0.1.13
 */
public interface Folks.IMable : Object
{
  /* FIXME: We have to use GenericArray<string> here rather than string[] as
   * null-terminated arrays aren't supported as generic types yet. It would be
   * best if we changed to using a proper ordered set datatype, which inherently
   * disallows duplicates, while retaining the ordering of its members.
   * (bgo#627483) */
  /**
   * A mapping of IM protocol to an ordered set of IM addresses.
   *
   * Each mapping is from an arbitrary protocol identifier to a set of IM
   * addresses on that protocol for the contact, listed in preference order.
   * The most-preferred IM address for each protocol comes first in that
   * protocol's list.
   *
   * There must be no duplicate IM addresses in each ordered set, though a given
   * IM address may be present in the sets for different protocols.
   *
   * All the IM addresses must be normalised using
   * {@link IMable.normalise_im_address} before being added to this property.
   *
   * @since 0.1.13
   */
  public abstract HashTable<string, GenericArray<string>> im_addresses
    {
      get; set;
    }

  /**
   * Normalise an IM address so that it's suitable for string comparison.
   *
   * IM addresses for various protocols can be represented in different ways,
   * only one of which is canonical. In order to allow simple string comparisons
   * of IM addresses to work, the IM addresses must be normalised beforehand.
   *
   * @param im_address the address to normalise
   * @param protocol the protocol of this im_address
   *
   * @since 0.2.0
   */
  public static string normalise_im_address (string im_address, string protocol)
    {
      string normalised;

      if (protocol == "aim" || protocol == "myspace")
        {
          normalised = im_address.replace (" ", "").down ();
        }
      else if (protocol == "irc" || protocol == "yahoo" ||
          protocol == "yahoojp" || protocol == "groupwise")
        {
          normalised = im_address.down ();
        }
      else if (protocol == "jabber")
        {
          /* Parse the JID */
          string[] parts = im_address.split ("/", 2);

          return_val_if_fail (parts.length >= 1, null);

          string resource = null;
          if (parts.length == 2)
            resource = parts[1];

          parts = parts[0].split ("@", 2);

          return_val_if_fail (parts.length >= 1, null);

          string node, domain;
          if (parts.length == 2)
            {
              node = parts[0];
              domain = parts[1];
            }
          else
            {
              node = null;
              domain = parts[0];
            }

          return_val_if_fail (node == null || node != "", null);
          return_val_if_fail (domain != null && domain != "", null);
          return_val_if_fail (resource == null || resource != "", null);

          domain = domain.down ();
          if (node != null)
            node = node.down ();

          /* Build a new JID */
          if (node != null && resource != null)
            normalised = "%s@%s/%s".printf (node, domain, resource);
          else if (node != null)
            normalised = "%s@%s".printf (node, domain);
          else if (resource != null)
            normalised = "%s/%s".printf (domain, resource);
          else
            assert_not_reached ();
        }
      else
        {
          /* Fallback */
          normalised = im_address;
        }

      return normalised.normalize ();
    }
}
