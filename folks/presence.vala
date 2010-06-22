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
  /**
   * Presence is unset. (Default.)
   */
  UNSET,

  /**
   * User is offline.
   */
  OFFLINE,

  /**
   * User is available.
   */
  AVAILABLE,

  /**
   * User is away.
   */
  AWAY,

  /**
   * User is away for an extended period.
   */
  EXTENDED_AWAY,

  /**
   * User is online but hidden.
   */
  HIDDEN,

  /**
   * User is busy.
   */
  BUSY,

  /**
   * Presence is unknown.
   */
  UNKNOWN,

  /**
   * Presence is invalid.
   */
  ERROR
}

/**
 * Interface for {@link Persona}s or {@link Individual}s which have a presence;
 * their current availability, such as for chatting.
 */
public interface Folks.Presence : Object
{
  public abstract Folks.PresenceType presence_type
    {
      get; set; default = Folks.PresenceType.UNSET;
    }
  public abstract string presence_message { get; set; default = ""; }

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

  public static uint typecmp (PresenceType type_a, PresenceType type_b)
    {
      return type_availability (type_a) - type_availability (type_b);
    }

  public bool is_online ()
    {
      return (typecmp (this.presence_type, PresenceType.OFFLINE) > 0);
    }
}
