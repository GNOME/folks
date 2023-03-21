/*
 * Copyright (C) 2012-2013 Collabora Ltd.
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
 *       Arun Raghavan <arun.raghavan@collabora.co.uk>
 *       Gustavo Padovan <gustavo.padovan@collabora.co.uk>
 *       Matthieu Bouron <matthieu.bouron@collabora.com>
 */

using GLib;

/* Reference:
 * http://git.kernel.org/cgit/bluetooth/bluez.git/tree/doc/device-api.txt */
namespace org
  {
    namespace bluez
      {
        [DBus (name = "org.bluez.Error")]
        public errordomain Error
          {
            NOT_READY,
            FAILED,
            IN_PROGRESS,
            ALREADY_CONNECTED,
            NOT_CONNECTED,
            DOES_NOT_EXIST,
            CONNECT_FAILED,
            NOT_SUPPORTED,
            INVALID_ARGUMENTS,
            AUTHENTICATION_CANCELED,
            AUTHENTICATION_FAILED,
            AUTHENTICATION_REJECTED,
            AUTHENTICATION_TIMEOUT,
            CONNECTION_ATTEMPT_FAILED
          }

        [DBus (name = "org.bluez.Device1")]
        public interface Device : Object
          {
            /* Methods. */
            [DBus (name = "Connect")]
            public abstract void connect ()
                throws org.bluez.Error, DBusError, IOError;

            [DBus (name = "Disconnect")]
            public abstract void disconnect ()
                throws org.bluez.Error, DBusError, IOError;

            [DBus (name = "DisconnectProfile")]
            public abstract void disconnect_profile (string uuid)
                throws org.bluez.Error, DBusError, IOError;

            [DBus (name = "Pair")]
            public abstract void pair ()
                throws org.bluez.Error, DBusError, IOError;

            [DBus (name = "CancelPairing")]
            public abstract void cancel_pairing ()
                throws org.bluez.Error, DBusError, IOError;

            /* Properties. */
            [DBus (name = "Address")]
            public abstract string address { owned get; }

            [DBus (name = "Name")]
            public abstract string name { owned get; }

            [DBus (name = "Icon")]
            public abstract string icon { owned get; }

            [DBus (name = "Class")]
            public abstract uint32 bluetooth_class { get; }

            [DBus (name = "Appearance")]
            public abstract uint16 appearance { get; }

            [DBus (name = "UUIDs")]
            public abstract string[] uuids { owned get; }

            [DBus (name = "Paired")]
            public abstract bool paired { get; }

            [DBus (name = "Connected")]
            public abstract bool connected { get; }

            [DBus (name = "Trusted")]
            public abstract bool trusted { get; set; }

            [DBus (name = "Blocked")]
            public abstract bool blocked { get; set; }

            [DBus (name = "Alias")]
            public abstract string alias { owned get; set; }

            [DBus (name = "Adapter")]
            public abstract ObjectPath adapter { owned get; }

            [DBus (name = "LegacyPairing")]
            public abstract bool legacy_pairing { get; }

            [DBus (name = "Modalias")]
            public abstract string mod_alias { owned get; }

            [DBus (name = "RSSI")]
            public abstract int16 rssi { get; }
          }
      }
  }
