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
using TelepathyGLib;
using Folks;

private struct AccountFavourites
{
  ObjectPath account_path;
  string[] ids;
}

[DBus (name = "org.freedesktop.Telepathy.Logger.DRAFT")]
private interface LoggerIface : Object
{
  public abstract async AccountFavourites[] get_favourite_contacts ()
      throws DBus.Error;
  public abstract async void add_favourite_contact (
      ObjectPath account_path, string id) throws DBus.Error;
  public abstract async void remove_favourite_contact (
      ObjectPath account_path, string id) throws DBus.Error;

  public abstract signal void favourite_contacts_changed (
      ObjectPath account_path, string[] added, string[] removed);
}

internal class Logger : GLib.Object
{
  private static LoggerIface _logger;
  private string _account_path;

  public signal void invalidated ();
  public signal void favourite_contacts_changed (string[] added,
      string[] removed);

  public Logger (string account_path) throws DBus.Error
    {
      if (this._logger == null)
        {
          /* Create a logger proxy for favourites support */
          /* FIXME: This should be ported to the Vala GDBus stuff and made
           * async, but that depends on
           * https://bugzilla.gnome.org/show_bug.cgi?id=622611 being fixed.
           * FIXME: If this is made async, race conditions may appear in
           * TpfPersonaStore, which will need to be prevented. e.g.
           * change_is_favourite() may get called before logger initialisation
           * is complete; favourites-change requests should be queued. */
          /* FIXME: Before being ported to use GDBus, this should use
           * dbus_conn.get_object_for_name_owner() so that it behaves better if
           * the logger service disappears. This is, however, blocked by:
           * https://bugzilla.gnome.org/show_bug.cgi?id=623198 */
          var dbus_conn = DBus.Bus.get (DBus.BusType.SESSION);
          this._logger = dbus_conn.get_object (
              "org.freedesktop.Telepathy.Logger",
              "/org/freedesktop/Telepathy/Logger",
              "org.freedesktop.Telepathy.Logger.DRAFT") as LoggerIface;

          /* Failure? */
          if (this._logger == null)
            {
              this.invalidated ();
              return retval;
            }

          this._logger.destroy.connect (() =>
            {
              /* We've lost the connection to the logger service, so invalidate
               * this logger proxy (and all the others too). */
              this._logger = null;
              this.invalidated ();
            });
        }

      this._account_path = account_path;
      this._logger.favourite_contacts_changed.connect ((ap, a, r) =>
        {
          if (ap != this._account_path)
            return;

          this.favourite_contacts_changed (a, r);
        });
    }

  public async string[] get_favourite_contacts () throws DBus.Error
    {
      /* Invalidated */
      if (this._logger == null)
        return {};

      AccountFavourites[] favs = yield this._logger.get_favourite_contacts ();

      foreach (AccountFavourites account in favs)
        {
          /* We only want the favourites from this account */
          if (account.account_path == this._account_path)
            return account.ids;
        }

      return {};
    }

  public async void add_favourite_contact (string id) throws DBus.Error
    {
      /* Invalidated */
      if (this._logger == null)
        return;

      yield this._logger.add_favourite_contact (
          new ObjectPath (this._account_path), id);
    }

  public async void remove_favourite_contact (string id) throws DBus.Error
    {
      /* Invalidated */
      if (this._logger == null)
        return;

      yield this._logger.remove_favourite_contact (
          new ObjectPath (this._account_path), id);
    }
}
