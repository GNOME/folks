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

using GLib;

/**
 * This interface contains the birth date of a {@link Persona} and
 * {@link Individual}
 *
 * @since 0.3.UNRELEASED
 */
public interface Folks.BirthdayOwner : Object
{
  /**
   * The birthday of the {@link Persona} and
   * {@link Individual}
   *
   * @since 0.3.UNRELEASED
   */
  public abstract DateTime birthday { get; set; }

  /**
   * The event id from the source calenar
   *
   * @since 0.3.UNRELEASED
   */
  public abstract string calendar_event_id { get; set; }
}
