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

namespace org
  {
    namespace bluez
      {
        namespace obex
          {
            [DBus (name = "org.bluez.obex.Client1")]
            public interface Client : Object
              {
                [DBus (name = "CreateSession")]
                public async abstract ObjectPath create_session (string address,
                    HashTable<string, Variant> args) throws DBusError, IOError;
                [DBus (name = "RemoveSession")]
                public async abstract void remove_session (ObjectPath session)
                    throws DBusError, IOError;
              }

            [DBus (name = "org.bluez.obex.PhonebookAccess1")]
            public interface PhonebookAccess : Object
              {
                /* Returned by List () */
                public struct PhonebookEntry
                  {
                    public string vcard;
                    public string name;
                  }

                public struct PhonebookPull
                  {
                    public ObjectPath path;
                    public HashTable<string, Variant> props;
                  }

                [DBus (name = "Select")]
                public abstract void select (string location, string phonebook)
                    throws DBusError, IOError;
                [DBus (name = "List")]
                public abstract PhonebookEntry[] list (
                    HashTable<string, Variant> filters)
                    throws DBusError, IOError;
                [DBus (name = "ListFilterFields")]
                public abstract string[] list_filter_fields ()
                    throws DBusError, IOError;
                [DBus (name = "PullAll")]
                public abstract void pull_all (string target,
                    HashTable<string, Variant> filters, out string path,
                    out HashTable<string, Variant> props)
                    throws DBusError, IOError;
              }

            [DBus (name = "org.bluez.obex.Transfer1")]
            public interface Transfer : Object
              {
                [DBus (name = "Cancel")]
                public abstract void cancel () throws DBusError, IOError;
                [DBus (name = "Status")]
                public abstract string status { owned get; }
                [DBus (name = "Session")]
                public abstract ObjectPath session { owned get; }
                [DBus (name = "Name")]
                public abstract string name { owned get; }
                [DBus (name = "Type")]
                public abstract string transfer_type { owned get; }
                [DBus (name = "Time")]
                public abstract int64 time { get; }
                [DBus (name = "Size")]
                public abstract uint64 size { get; }
                [DBus (name = "Transferred")]
                public abstract uint64 transferred { get; }
                [DBus (name = "Filename")]
                public abstract string filename { owned get; }
              }
          }
      }
  }
