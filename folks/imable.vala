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
 * IM addresses exposed by an object implementing {@link Presence}.
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
   */
  public abstract HashTable<string, GenericArray<string>> im_addresses
    {
      get; set;
    }
}
