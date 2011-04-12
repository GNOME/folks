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
 * This interface represents the list of IDs corresponding
 * to {@link Persona}s from backends with write support so
 * that they can be linked.
 *
 * @since 0.5.0
 */
public interface Folks.LocalIdDetails : Object
{
  /**
   * The IDs corresponding to contacts in a
   * backend that we fully trust.
   *
   * @since 0.5.0
   */
  public abstract HashSet<string> local_ids { get; set; }
}
