/*
 * Copyright (C) 2013 Collabora Ltd.
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
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;

/**
 * Vala wrapper for the standard org.freedesktop.DBus.Mock interface.
 *
 * This is exposed by python-dbusmock as the primary means of controlling a
 * mocked up D-Bus service.
 *
 * @since 0.9.7
 */

/* Reference:
 * http://bazaar.launchpad.net/~pitti/python-dbusmock/trunk/view/head:/README.rst */
namespace org
  {
    namespace freedesktop
      {
        namespace DBus
          {
            [DBus (name = "org.freedesktop.DBus.Mock")]
            public interface Mock : Object
              {
                /* Signals. */
                [DBus (name = "MethodCalled")]
                public signal void method_called (string method_name,
                    Variant[] args);

                /* Methods. */
                [DBus (name = "AddMethod")]
                public abstract void add_method (string interface_name,
                    string name, string in_sig, string out_sig, string code)
                        throws DBusError, IOError;

                /* Parameter to AddMethods(). */
                public struct Method
                  {
                    public string name;
                    public string in_sig;
                    public string out_sig;
                  }

                [DBus (name = "AddMethods")]
                public abstract void add_methods (string interface_name,
                    Method[] methods) throws DBusError, IOError;

                [DBus (name = "AddObject")]
                public abstract void add_object (string path,
                    string interface_name,
                    HashTable<string, Variant> properties, Method[] methods)
                        throws DBusError, IOError;

                [DBus (name = "AddProperties")]
                public abstract void add_properties (string interface_name,
                    HashTable<string, Variant> properties)
                        throws DBusError, IOError;

                [DBus (name = "AddProperty")]
                public abstract void add_property (string interface_name,
                    string name, Variant val) throws DBusError, IOError;

                [DBus (name = "AddTemplate")]
                public abstract void add_template (string template_name,
                    HashTable<string, Variant> template_params)
                        throws DBusError, IOError;

                [DBus (name = "ClearCalls")]
                public abstract void clear_calls () throws DBusError, IOError;

                [DBus (name = "EmitSignal")]
                public abstract void emit_signal (string interface_name,
                    string name, string signature, Variant[] args)
                        throws DBusError, IOError;

                /* Returned by GetCalls(). */
                public struct Call
                  {
                    public uint64 call_time;
                    public string method_name;
                    public Variant[] args;
                  }

                [DBus (name = "GetCalls")]
                public abstract Call[] get_calls () throws DBusError, IOError;

                /* Returned by GetMethodCalls(). */
                public struct MethodCall
                  {
                    public uint64 call_time;
                    public Variant[] args;
                  }

                [DBus (name = "GetMethodCalls")]
                public abstract MethodCall[] get_method_calls (string method)
                    throws DBusError, IOError;

                [DBus (name = "RemoveObject")]
                public abstract void remove_object (string path)
                    throws DBusError, IOError;

                [DBus (name = "Reset")]
                public abstract void reset () throws DBusError, IOError;
              }
          }
      }
  }
