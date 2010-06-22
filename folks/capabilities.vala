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
 * Flag values for the capabilities an object implementing {@link Capabilities}
 * could possibly have, as a bitmask.
 */
public enum Folks.CapabilitiesFlags {
  /**
   * No capabilities. Mutually exclusive with the other values.
   */
  NONE = 0,

  /**
   * Audio chat support.
   */
  AUDIO = 1 << 0,

  /**
   * Video chat support.
   */
  VIDEO = 1 << 1,

  /**
   * File transfer support.
   */
  FILE_TRANSFER = 1 << 2,

  /**
   * Telepathy tubes support.
   */
  STREAM_TUBE = 1 << 3,

  /**
   * Unknown set of capabilities. Mutually exclusive with the other values.
   */
  UNKNOWN = 1 << 7,
}

/**
 * Interface exposing the capabilities of the {@link Persona} or
 * {@link Individual} implementing it, such as whether they can do video chats
 * or file transfers.
 */
public interface Folks.Capabilities : Object
{
  public abstract CapabilitiesFlags capabilities
    {
      get; set; default = CapabilitiesFlags.NONE;
    }
}
