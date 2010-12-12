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
 *       Travis Reitter <travis.reitter@collabora.co.uk>
 */

using GLib;

/**
 * Interface for classes which represent contacts which have an avatar
 * (pictorial representation), such as {@link Persona} and {@link Individual}.
 */
public interface Folks.HasAvatar : Object
{
  /**
   * An avatar for the contact.
   *
   * An avatar is a small image file which represents the contact. It may be
   * `null` if unset.
   */
  public abstract File avatar { get; set; }
}
