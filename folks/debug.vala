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

internal class Folks.Debug : Object
{
  private enum Domains {
    /* Zero is used for "no debug spew" */
    CORE = 1 << 0,
    TELEPATHY_BACKEND = 1 << 1,
    KEY_FILE_BACKEND = 1 << 2
  }

  private static weak Debug _instance;
  private HashSet<string> _domains;
  private bool _all = false;

  internal void _set_flags (string? debug_flags)
    {
      this._all = false;
      this._domains = new HashSet<string> (str_hash, str_equal);

      if (debug_flags == null || debug_flags == "")
        return;

      var domains_split = debug_flags.split (",");
      foreach (var domain in domains_split)
        {
          var domain_lower = domain.down ();

          if (GLib.strcmp (domain_lower, "all") == 0)
            this._all = true;
          else
            this._domains.add (domain_lower);
        }
    }

  /* turn off debug output for the given domain unless it was in the FOLKS_DEBUG
   * environment variable (or 'all' was set) */
  internal void _register_domain (string domain)
    {
      if (this._all || this._domains.contains (domain.down ()))
        {
          /* FIXME: shouldn't need to cast. See bgo#638682 */
          Log.set_handler (domain, LogLevelFlags.LEVEL_MASK,
              (LogFunc) Log.default_handler);
          return;
        }

      /* Install a log handler which will blackhole the log message.
       * Other log messages will be printed out by the default log handler. */
      Log.set_handler (domain, LogLevelFlags.LEVEL_DEBUG,
          (domain_arg, flags, message) => {});
    }

  internal static Debug dup ()
    {
      if (_instance == null)
        {
          /* use an intermediate variable to force a strong reference */
          var new_instance = new Debug ();
          _instance = new_instance;

          return new_instance;
        }

      return _instance;
    }

  ~Debug ()
    {
      /* manually clear the singleton _instance */
      _instance = null;
    }
}
