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
 *       Marco Barisione <marco.barisione@collabora.co.uk>
 */

using GLib;

/**
 * Interface for classes that have email addresses, such as {@link Persona}
 * and {@link Individual}.
 *
 * @since 0.3.5
 */
public interface Folks.EmailDetails : Object
{
  /**
   * The email addresses of the contact.
   *
   * @since 0.3.5
   */
  public abstract List<FieldDetails> email_addresses { get; set; }
}
