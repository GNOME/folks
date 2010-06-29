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
 * Interface for {@link Persona}s or {@link Individual}s which can be grouped
 * into sets of similar objects.
 */
public interface Folks.Groups : Object
{
  /**
   * A mapping of group ID to whether the contact is a member.
   *
   * Freeform group IDs are mapped to a boolean which is `true` if the
   * contact is a member of the group, and `false` otherwise.
   */
  public abstract HashTable<string, bool> groups { get; set; }

  /**
   * Add or remove the contact from the specified group.
   *
   * If `is_member` is `true`, the contact will be added to the `group`. If
   * it is `false`, they will be removed from the `group`.
   *
   * @param group a freeform group identifier
   * @param is_member whether the contact should be a member of the group
   */
  public abstract void change_group (string group, bool is_member);

  /**
   * Emitted when the contact's membership status changes for a group.
   *
   * This is emitted if the contact becomes a member of a group they weren't in
   * before, or leaves a group they were in.
   *
   * @param group a freeform group identifier for the group being left or joined
   * @param is_member whether the contact is joining or leaving the group
   */
  public signal void group_changed (string group, bool is_member);
}
