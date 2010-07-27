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
   * The reason a group member has changed its membership in the group.
   *
   * These closely follow the
   * [[http://telepathy.freedesktop.org/spec/Channel_Interface_Group.html#Channel_Group_Change_Reason|Channel_Group_Change_Reason]]
   * interface in the Telepathy specification.
   */
  public static enum ChangeReason
    {
      /* No reason was provided for this change.
       *
       * This is used when a member joins or leaves a group normally. */
      NONE = 0,
      /* The change is due to a member going offline.
       *
       * Also used when member is already offline, but this wasn't known
       * previously. */
      OFFLINE = 1,
      /* The change is due to a kick operation. */
      KICKED = 2,
      /* The change is due to a busy indication. */
      BUSY = 3,
      /* The change is due to an invitation. */
      INVITED = 4,
      /* The change is due to a kick+ban operation. */
      BANNED = 5,
      /*  The change is due to an error occurring. */
      ERROR = 6,
      /* The change is because the requested member does not exist.
       *
       * For instance, if the user invites a nonexistent contact to a chatroom
       * or attempts to call a nonexistent contact */
      INVALID_MEMBER = 7,
      /* The change is because the requested contact did not respond. */
      NO_ANSWER = 8,
      /* The change is because a member's unique identifier changed.
       *
       * There must be exactly one member in the removed set and exactly one
       * member in one of the added sets. */
      RENAMED = 9,
      /* The change is because there was no permission to contact the requested
       * member. */
      PERMISSION_DENIED = 10,
      /* If members are removed with this reason code, the change is because the
       * group has split into unconnected parts which can only communicate
       * within themselves (e.g. netsplits on IRC use this reason code).
       *
       * If members are added with this reason code, the change is because
       * unconnected parts of the group have rejoined. If this channel carries
       * messages (e.g. Text or Tubes channels) applications must assume that
       * the contacts being added are likely to have missed some messages as a
       * result of the separation, and that the contacts in the group are likely
       * to have missed some messages from the contacts being added.
       *
       * Note that from the added contacts' perspective, they have been in the
       * group all along, and the contacts we indicate to be in the group
       * (including the local user) have just rejoined the group with reason
       * Separated. Application protocols in Tubes should be prepared to cope
       * with this situation. */
      SEPARATED = 11
    }

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
  public async abstract void change_group (string group, bool is_member)
    throws GLib.Error;

  /**
   * Emitted when the contact's membership status changes for a group.
   *
   * This is emitted if the contact becomes a member of a group they weren't in
   * before, or leaves a group they were in.
   *
   * @param group a freeform group identifier for the group being left or joined
   * @param is_member whether the contact is joining or leaving the group
   */
  public async signal void group_changed (string group, bool is_member);
}
