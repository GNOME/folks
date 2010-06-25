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
 * The possible presence states an object implementing {@link Presence} could be
 * in.
 *
 * These closely follow the
 * [[http://telepathy.freedesktop.org/spec/Connection_Interface_Simple_Presence.html#Connection_Presence_Type|SimplePresence]]
 * interface in the Telepathy specification.
 */
public enum Folks.PresenceType {
  UNSET,
  OFFLINE,
  AVAILABLE,
  AWAY,
  EXTENDED_AWAY,
  HIDDEN,
  BUSY,
  UNKNOWN,
  ERROR
}

/**
 * Interface exposing a {@link Persona}'s or {@link Individual}'s presence;
 * their current availability, such as for chatting. If the {@link Backend}
 * providing the {@link Persona} doesn't support presence, the {@link Persona}'s
 * `presence_type` will be set to {@link PresenceType.UNSET} and their
 * `presence_message` will be an empty string.
 */
public interface Folks.Presence : Object
{
  /**
   * The contact's presence type.
   *
   * Each contact can have one and only one presence type at any one time,
   * representing their availability for communication. The default presence
   * type is {@link PresenceType.UNSET}.
   */
  public abstract Folks.PresenceType presence_type
    {
      get; set; default = Folks.PresenceType.UNSET;
    }

  /**
   * The contact's presence message.
   *
   * This is a short message written by the contact to add detail to their
   * presence type ({@link Folks.Presence.presence_type}). If the contact hasn't
   * set a message, it will be an empty string.
   */
  public abstract string presence_message { get; set; default = ""; }

  /* Rank the presence types for comparison purposes, with higher numbers
   * meaning more available */
  private static uint type_availability (PresenceType type)
    {
      switch (type)
        {
          case PresenceType.UNSET:
            return 0;
          case PresenceType.UNKNOWN:
            return 1;
          case PresenceType.ERROR:
            return 2;
          case PresenceType.OFFLINE:
            return 3;
          case PresenceType.HIDDEN:
            return 4;
          case PresenceType.EXTENDED_AWAY:
            return 5;
          case PresenceType.AWAY:
            return 6;
          case PresenceType.BUSY:
            return 7;
          case PresenceType.AVAILABLE:
            return 8;
          default:
            return 1;
        }
    }

  /**
   * Compare two {@link PresenceType}s.
   *
   * `0` will be returned if the types are equal, a negative number will be
   * returned if `type_a` is more available than `type_b`, and a positive
   * number will be returned if the opposite is true.
   *
   * @return a number representing the similarity of the two types
   */
  public static uint typecmp (PresenceType type_a, PresenceType type_b)
    {
      return type_availability (type_a) - type_availability (type_b);
    }

  /**
   * Whether the contact is online.
   *
   * This will be `true` if the contact's presence type is higher than
   * {@link PresenceType.OFFLINE}, as determined by {@link Presence.typecmp}.
   *
   * @return `true` if the contact is online, `false` otherwise
   */
  public bool is_online ()
    {
      return (typecmp (this.presence_type, PresenceType.OFFLINE) > 0);
    }
}
