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
  NONE = 0,
  AUDIO = 1 << 0,
  VIDEO = 1 << 1,
  FILE_TRANSFER = 1 << 2,
  STREAM_TUBE = 1 << 3,
  UNKNOWN = 1 << 7,
}

/**
 * Interface exposing the capabilities of the {@link Persona} or
 * {@link Individual} implementing it, such as whether they can do video chats
 * or file transfers.
 */
public interface Folks.Capabilities : Object
{
  /**
   * A bitmask of the contact's capabilities.
   *
   * The value will either be {@link CapabilitiesFlags.NONE} (the default),
   * {@link CapabilitiesFlags.UNKNOWN} or a combination of the other flags in
   * {@link CapabilitiesFlags}.
   */
  public abstract CapabilitiesFlags capabilities
    {
      get; set; default = CapabilitiesFlags.NONE;
    }
}
