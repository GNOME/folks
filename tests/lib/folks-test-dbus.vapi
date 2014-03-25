/*
 * folks-test-dbus.vapi — a tweaked copy of GTestDBus wrapped in Vala
 *
 * Copyright © 2014 Philip Withnall
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 *
 * Authors:
 *      Philip Withnall <philip@tecnocode.co.uk>
 */

[CCode (gir_namespace = "Folks", gir_version = "0.6")]
namespace Folks
{
  [CCode (cheader_filename = "gtestdbus.h", cprefix = "FOLKS_TEST_DBUS_")]
  [Flags]
  public enum TestDBusFlags {
    NONE,
    SESSION_BUS,
    SYSTEM_BUS
  }

  [CCode (cheader_filename = "gtestdbus.h")]
  public class TestDBus : GLib.Object
  {
    [CCode (has_construct_function = false)]
    public TestDBus (Folks.TestDBusFlags flags);
    public void add_service_dir (string path);
    public void down ();
    public unowned string get_bus_address ();
    public Folks.TestDBusFlags get_flags ();
    public void stop ();
    public static void unset ();
    public void up ();
    public Folks.TestDBusFlags flags { get; construct; }
  }
}

/* vim:set ft=vala: */
