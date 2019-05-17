/*
 * Copyright © 2013 Intel Corporation
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
 *    Simon McVittie <simon.mcvittie@collabora.co.uk>
 */

/**
 * helper-delete-contacts --uid=UID
 *
 * Delete every contact from the Evolution Data Server address book
 * with the given UID.
 *
 * This utility must be called in a Folks test environment, with
 * DBUS_SESSION_BUS_ADDRESS pointing to a temporary D-Bus session and
 * XDG_CONFIG_HOME, XDG_DATA_HOME, XDG_CACHE_HOME pointing into a temporary
 * directory.
 */
public class Main
{
  private static void _remove_all (string uid) throws GLib.Error
    {
      var registry = new E.SourceRegistry.sync ();
      var source = registry.ref_source (uid);
      assert (source.uid == uid);
      var book_client = E.BookClient.connect_sync (source, 1);

      SList<string> uids;
      book_client.get_contacts_uids_sync (
          "(contains \"x-evolution-any-field\" \"\")", out uids);
      book_client.remove_contacts_sync (uids, E.BookOperationFlags.NONE);
    }

  private static string _uid = "";
  private const GLib.OptionEntry[] _options = {
      { "uid", 'u', 0, OptionArg.STRING, ref Main._uid,
          "Address book uid", "UID" },
      { null }
  };

  public static int main (string[] args)
    {
      Intl.setlocale (LocaleCategory.ALL, "");

      if (Environment.get_variable ("FOLKS_TESTS_SANDBOXED_DBUS") != "no-services")
        error ("e-d-s helpers must be run in a private D-Bus session with " +
            "e-d-s services");

      try
        {
          var context = new OptionContext ("- Delete all e-d-s contacts");
          context.set_help_enabled (true);
          context.add_main_entries (Main._options, null);
          context.parse (ref args);
        }
      catch (OptionError e)
        {
          stderr.printf ("Error parsing arguments: %s\n", e.message);
          return 2;
        }

      if (Main._uid == "")
        {
          stderr.printf ("The --uid=UID option is required\n");
          return 2;
        }

      try
        {
          Main._remove_all (Main._uid);
        }
      catch (Error e)
        {
          stderr.printf ("Error: %s\n", e.message);
          return 1;
        }

      return 0;
    }
}
