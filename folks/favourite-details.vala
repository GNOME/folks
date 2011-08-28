/*
 * Copyright (C) 2010 Collabora Ltd.
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
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;

/**
 * Interface exposing a {@link Persona}'s or {@link Individual}'s user-defined
 * status as a favourite.
 */
public interface Folks.FavouriteDetails : Object
{
  /**
   * Whether this contact is a user-defined favourite.
   */
  public abstract bool is_favourite { get; set; }

  /**
   * Change whether the contact is a user-defined favourite.
   *
   * It's preferred to call this rather than setting
   * {@link FavouriteDetails.is_favourite} directly, as this method gives error
   * notification and will only return once the favouriteness has been written
   * to the relevant backing store (or the operation's failed).
   *
   * @param is_favourite `true` if the contact is a favourite; `false` otherwise
   * @throws PropertyError if setting the favouriteness failed
   * @since UNRELEASED
   */
  public virtual async void change_is_favourite (bool is_favourite)
      throws PropertyError
    {
      /* Default implementation. */
      throw new PropertyError.NOT_WRITEABLE (
          _("Favourite status is not writeable on this contact."));
    }
}
