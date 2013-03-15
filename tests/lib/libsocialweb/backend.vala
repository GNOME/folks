/*
 * Copyright (C) 2011 Collabora Ltd.
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
 * Authors: Alban Crequy <alban.crequy@collabora.co.uk>
 *
 */

using Gee;
using GLib;

[DBus (name = "org.gnome.libsocialweb.ContactView")]
public interface LibsocialwebTest.ContactView : DBusProxy
{
  public struct ContactsAddedElement
    {
      public string service;
      public string id;
      public int64 time;
      [DBus (signature = "a{sas}")]
      public Variant attrs;
    }

  public struct ContactsRemovedElement
    {
      public string service;
      public string id;
    }

  public abstract async void Close () throws GLib.IOError;
  public abstract async void Refresh () throws GLib.IOError;
  public abstract async void Start () throws GLib.IOError;
  public abstract async void Stop () throws GLib.IOError;

  [DBus (signature = "a(ssxa{sas})")]
  public signal void ContactsAdded (ContactsAddedElement[] contacts);
  [DBus (signature = "a(ssxa{sas})")]
  public signal void ContactsChanged (ContactsAddedElement[] contacts);
  [DBus (signature = "a(ss)")]
  public signal void ContactsRemoved (ContactsRemovedElement[] contacts);
}

[DBus (name = "org.gnome.libsocialweb.ContactView")]
public class LibsocialwebTest.LibsocialwebContactViewTest : Object
{
  public struct ContactsAddedElement
    {
      public string service;
      public string id;
      public int64 time;
      [DBus (signature = "a{sas}")]
      public Variant attrs;
    }

  public struct ContactsRemovedElement
    {
      public string service;
      public string id;
    }

  public string query;
  HashTable<string, string> p;
  public string path;

  public LibsocialwebContactViewTest (string query,
      HashTable<string, string> p, string path)
    {
      this.query = query;
      this.p = p;
      this.path = path;
    }

  public void Close ()
    {
    }

  public void Refresh ()
    {
    }

  public void Start ()
    {
      debug ("Start() called.");
      StartCalled (this.path);
    }

  public void Stop ()
    {
    }

  [DBus (visible = false)]
  public signal void CloseCalled (string path);
  [DBus (visible = false)]
  public signal void RefreshCalled (string path);
  [DBus (visible = false)]
  public signal void StartCalled (string path);
  [DBus (visible = false)]
  public signal void StopCalled (string path);

  [DBus (signature = "a(ssxa{sas})")]
  public signal void ContactsAdded (ContactsAddedElement[] contacts);
  [DBus (signature = "a(ssxa{sas})")]
  public signal void ContactsChanged (ContactsAddedElement[] contacts);
  [DBus (signature = "a(ss)")]
  public signal void ContactsRemoved (ContactsRemovedElement[] contacts);

  /* The D-Bus signals cannot be emitted by just calling the function. See:
   * https://bugzilla.gnome.org/show_bug.cgi?id=645528
   * So we use the following methods for now.
   */
  [DBus (visible = false)]
  public void EmitContactsAdded (string text)
    {
      try
        {
          var conn = Bus.get_sync (BusType.SESSION);
          Variant v = new Variant.parsed (text);
          conn.emit_signal (null, this.path,
                LibsocialwebTest.Backend.LIBSOCIALWEB_IFACE + ".ContactView",
                "ContactsAdded", v);
        }
      catch (GLib.IOError e)
        {
          assert_not_reached ();
        }
      catch (GLib.Error e)
        {
          assert_not_reached ();
        }
    }
  [DBus (visible = false)]
  public void EmitContactsChanged (string text)
    {
      try
        {
          var conn = Bus.get_sync (BusType.SESSION);
          Variant v = new Variant.parsed (text);
          conn.emit_signal (null, this.path,
                LibsocialwebTest.Backend.LIBSOCIALWEB_IFACE + ".ContactView",
                "ContactsChanged", v);
        }
      catch (GLib.IOError e)
        {
          assert_not_reached ();
        }
      catch (GLib.Error e)
        {
          assert_not_reached ();
        }
    }
  [DBus (visible = false)]
  public void EmitContactsRemoved (string text)
    {
      try
        {
          var conn = Bus.get_sync (BusType.SESSION);
          Variant v = new Variant.parsed (text);
          conn.emit_signal (null, this.path,
                LibsocialwebTest.Backend.LIBSOCIALWEB_IFACE + ".ContactView",
                "ContactsRemoved", v);
        }
      catch (GLib.IOError e)
        {
          assert_not_reached ();
        }
      catch (GLib.Error e)
        {
          assert_not_reached ();
        }
    }
}

[DBus (name = "org.gnome.libsocialweb.Service")]
public interface LibsocialwebTest.LibsocialwebServiceCapabilitiesTest : Object
{
  [DBus (name = "GetStaticCapabilities")]
  public abstract string[] GetStaticCapabilities () throws GLib.IOError;
}

[DBus (name = "org.gnome.libsocialweb.ContactsQuery")]
public interface LibsocialwebTest.LibsocialwebServiceQueryTest : Object
{
  [DBus (name = "OpenView")]
  public abstract ObjectPath OpenView (string query,
      HashTable<string, string> p) throws GLib.IOError;
}

[DBus (name = "org.gnome.libsocialweb.ContactsQuery")]
public class LibsocialwebTest.LibsocialwebServiceTest : Object,
    LibsocialwebTest.LibsocialwebServiceCapabilitiesTest,
    LibsocialwebTest.LibsocialwebServiceQueryTest
{
  static int view_count = 0;
  private string service_name;
  public Gee.HashMap<string,LibsocialwebTest.LibsocialwebContactViewTest>
      contact_views;

  public LibsocialwebServiceTest (string service_name)
    {
      this.service_name = service_name;
      this.contact_views = new Gee.HashMap<string,
          LibsocialwebTest.LibsocialwebContactViewTest>();
    }

  public ObjectPath OpenView (string query, HashTable<string, string> p)
    {
      string path = LibsocialwebTest.Backend.LIBSOCIALWEB_PATH + "/View"
          + view_count.to_string();
      try
        {
          var conn = Bus.get_sync (BusType.SESSION);
          LibsocialwebContactViewTest contact_view = new LibsocialwebContactViewTest
              (query, p, path);
          conn.register_object (path, contact_view);
          contact_views[path] = contact_view;
          LibsocialwebTest.LibsocialwebServiceTest.view_count++;
        }
      catch (GLib.IOError e)
        {
          assert_not_reached ();
        }

      OpenViewCalled (query, p, path);
      return new ObjectPath (path);
    }

  [DBus (visible = false)]
  public signal void OpenViewCalled (string query, HashTable<string, string> p,
                                     string path);

  public string[] GetStaticCapabilities ()
    {
      var ret = new string[0];
      ret += "has-contacts-query-iface";
      return ret;
    }
}

[DBus (name = "org.gnome.libsocialweb")]
public class LibsocialwebTest.LibsocialwebServerTest : Object
{
  private string[] services;

  public LibsocialwebServerTest ()
    {
      services = new string[0];
    }

  [DBus (name = "IsOnline")]
  public bool is_online ()
    {
      return true;
    }
  [DBus (name = "GetServices")]
  public string[] get_services ()
    {
      return services;
    }

  [DBus (visible = false)]
  public LibsocialwebTest.LibsocialwebServiceTest add_service
      (string service_name)
    {
      LibsocialwebServiceTest service
          = new LibsocialwebServiceTest (service_name);
      try
        {
          var conn = Bus.get_sync (BusType.SESSION);
          conn.register_object
              <LibsocialwebTest.LibsocialwebServiceCapabilitiesTest>
              (LibsocialwebTest.Backend.LIBSOCIALWEB_PATH + "/Service/"
                  + service_name, service);
          conn.register_object
              <LibsocialwebTest.LibsocialwebServiceQueryTest>
              (LibsocialwebTest.Backend.LIBSOCIALWEB_PATH + "/Service/"
                  + service_name, service);
        }
      catch (GLib.IOError e)
        {
          assert_not_reached ();
        }
      this.services += service_name;
      return service;
    }
}

public class LibsocialwebTest.Backend
{
  public static const string LIBSOCIALWEB_IFACE = "org.gnome.libsocialweb";
  public static const string LIBSOCIALWEB_PATH = "/org/gnome/libsocialweb";
  public static const string LIBSOCIALWEB_BUS_NAME = "org.gnome.libsocialweb";

  public bool debug { get; set; }
  private LibsocialwebServerTest lsw_server;
  private uint _name_id = 0;

  public signal void ready ();

  public Backend ()
    {
      this.debug = false;
    }

  public void set_up ()
    {
      lsw_server = new LibsocialwebServerTest ();
      try
        {
          var conn = Bus.get_sync (BusType.SESSION);
          conn.register_object (LIBSOCIALWEB_PATH, lsw_server);
        }
      catch (GLib.IOError e)
        {
          assert_not_reached ();
        }

      this._name_id = Bus.own_name (
        BusType.SESSION, LIBSOCIALWEB_BUS_NAME,
        BusNameOwnerFlags.NONE,
        on_bus_aquired,
        () =>
          {
            this.ready ();
          },
        () =>
          {
            message ("Could not aquire D-Bus name\n");
            assert_not_reached ();
          });
    }

  private void on_bus_aquired (DBusConnection conn)
    {
    }

  public LibsocialwebTest.LibsocialwebServiceTest add_service
      (string service_name)
    {
      return lsw_server.add_service (service_name);
    }

  public void tear_down ()
    {
      if (this._name_id != 0)
        {
          Bus.unown_name (this._name_id);
          this._name_id = 0;
        }
    }
}
