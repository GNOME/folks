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
 * helper-create-many-contacts --uid=UID [--n-contacts=N]
 *
 * Add N contacts (default 2000) to the Evolution Data Server address book
 * with the given UID.
 *
 * This utility must be called in a Folks test environment, with
 * DBUS_SESSION_BUS_ADDRESS pointing to a temporary D-Bus session and
 * XDG_CONFIG_HOME, XDG_DATA_HOME, XDG_CACHE_HOME pointing into a temporary
 * directory.
 *
 * By default, we use N numbered contacts with some easy test data (currently
 * full name, one email address and one ICQ number).
 *
 * If the environment variable $FOLKS_TESTS_REAL_VCARDS is set, it is a file
 * containing multiple vCards in text format. Put a source of test data there
 * (e.g. a copy of your personal address book). The first contacts in that
 * file will be used as the first contacts in the address book: if there
 * are more than N only the first N will be used, and if there are fewer than
 * N, the difference will be made up with numbered contacts.
 */
public class Main
{
  private static void _add_many (uint n_contacts, string uid) throws GLib.Error
    {
      var registry = new E.SourceRegistry.sync ();
      var source = registry.ref_source (uid);
      assert (source.uid == uid);
      var book_client = E.BookClient.connect_sync (source, 1);
      SList<E.Contact> contacts = null;

      var envvar = Environment.get_variable ("FOLKS_TESTS_REAL_VCARDS");

      uint n = 0;

      if (envvar != null)
        {
          /* Split at the boundaries between END:VCARD and BEGIN_VCARD,
           * without removing those tokens from the segments. */
          string[] cards;

          try
            {
              string text;
              FileUtils.get_contents ((!) envvar, out text);

              var regex = new Regex ("(?<=\r\nEND:VCARD)\r\n+(?=BEGIN:VCARD\r\n)",
                  RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS |
                  RegexCompileFlags.NEWLINE_LF);
              cards = regex.split_full (text);
            }
          catch (Error e)
            {
              error ("%s", e.message);
            }

          foreach (var card in cards)
            {
              if (n >= n_contacts)
                break;

              var contact = new E.Contact.from_vcard (card);

              /* If we got the contact from an e-d-s export, give it a new
               * unique uid. */
              contact.id = null;

              contacts.prepend (contact);
              n++;
            }
        }

      while (n < n_contacts)
        {
          var contact = new E.Contact ();

          contact.full_name = "Contact %u".printf (n);
          contact.email_1 = "contact%u@example.com".printf (n);
          contact.im_icq_home_1 = "%u".printf (n);

          contacts.prepend (contact);
          n++;
        }

      debug ("Importing %u contacts", n);

      SList<string> uids;
      try
        {
          book_client.add_contacts_sync (contacts, E.BookOperationFlags.NONE, out uids, null);
        }
      catch (Error e)
        {
          error ("%s", e.message);
        }

      debug ("Imported %u contacts", uids.length ());
    }

  private static int _n_contacts = 2000;
  private static string _uid = "";
  private const GLib.OptionEntry[] _options = {
      { "n-contacts", 'n', 0, OptionArg.INT, ref Main._n_contacts,
          "Number of contacts", "CONTACTS" },
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
          var context = new OptionContext ("- Create many e-d-s contacts");
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
          Main._add_many (Main._n_contacts, Main._uid);
        }
      catch (Error e)
        {
          stderr.printf ("Error: %s\n", e.message);
          return 1;
        }

      return 0;
    }
}
