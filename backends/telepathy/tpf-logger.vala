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
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;
using Gee;
using Tp;
using Folks;

private struct AccountFavourites
{
  DBus.ObjectPath account_path;
  string[] ids;
}

[DBus (name = "org.freedesktop.Telepathy.Logger.DRAFT")]
private interface LoggerIface : DBus.Object
{
  public abstract async AccountFavourites[] get_favourite_contacts ()
      throws DBus.Error;
  public abstract async void add_favourite_contact (
      DBus.ObjectPath account_path, string id) throws DBus.Error;
  public abstract async void remove_favourite_contact (
      DBus.ObjectPath account_path, string id) throws DBus.Error;

  public abstract signal void favourite_contacts_changed (
      DBus.ObjectPath account_path, string[] added, string[] removed);
}

internal class Logger : GLib.Object
{
  private static LoggerIface logger;
  private string account_path;

  public signal void favourite_contacts_changed (string[] added,
      string[] removed);

  public Logger (string account_path) throws DBus.Error
    {
      if (this.logger == null)
        {
          /* Create a logger proxy for favourites support */
          /* FIXME: This should be ported to the Vala GDBus stuff and made
           * async, but that depends on
           * https://bugzilla.gnome.org/show_bug.cgi?id=622611 being fixed. */
          var dbus_conn = DBus.Bus.get (DBus.BusType.SESSION);
          this.logger = dbus_conn.get_object (
              "org.freedesktop.Telepathy.Logger",
              "/org/freedesktop/Telepathy/Logger",
              "org.freedesktop.Telepathy.Logger.DRAFT") as LoggerIface;
        }

      this.account_path = account_path;
      this.logger.favourite_contacts_changed.connect ((ap, a, r) =>
        {
          if (ap != this.account_path)
            return;

          this.favourite_contacts_changed (a, r);
        });
    }

  public async string[] get_favourite_contacts () throws DBus.Error
    {
      AccountFavourites[] favs = yield this.logger.get_favourite_contacts ();

      foreach (AccountFavourites account in favs)
        {
          /* We only want the favourites from this account */
          if (account.account_path == this.account_path)
            return account.ids;
        }

      return {};
    }

  public async void add_favourite_contact (string id) throws DBus.Error
    {
      yield this.logger.add_favourite_contact (
          new DBus.ObjectPath (this.account_path), id);
    }

  public async void remove_favourite_contact (string id) throws DBus.Error
    {
      yield this.logger.remove_favourite_contact (
          new DBus.ObjectPath (this.account_path), id);
    }
}
