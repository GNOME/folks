/*
 * Copyright (C) 2012 Collabora Ltd.
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
 *          Jeremy Whiting <jeremy.whiting@collabora.co.uk>
 */

using GLib;

namespace org
  {
    namespace ofono
      {
        public struct ModemProperties
          {
            ObjectPath path;
            HashTable<string, Variant> properties;
          }

        [DBus (name = "org.ofono.Manager")]
        public interface Manager : Object
          {
            [DBus (name = "GetModems")]
            public abstract ModemProperties[] GetModems() throws DBusError, IOError;

            public signal void ModemAdded (ObjectPath path, HashTable<string, Variant> properties);
            public signal void ModemRemoved (ObjectPath path);
          }

        [DBus (name = "org.ofono.Phonebook")]
        public interface Phonebook : Object
          {
            [DBus (name = "Import")]
            public abstract string Import() throws DBusError, IOError;
          }

        [DBus (name = "org.ofono.SimManager")]
        public interface SimManager : Object
          {
              [DBus (name = "GetProperties")]
              public abstract HashTable<string, Variant> GetProperties() throws DBusError, IOError;

              public signal void PropertyChanged (string property, Variant value);
          }
      }
  }
