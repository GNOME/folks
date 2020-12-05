/*
 * Copyright (C) 2013 Philip Withnall
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Authors:
 *   Philip Withnall <philip@tecnocode.co.uk>
 */

using Folks;
using GLib;
using Gee;
using TelepathyGLib;
using Zeitgeist;

/**
 * Zeitgeist code for libfolks-telepathy.la. This is separated out from
 * tpf-persona-store.vala so that it can be conditionally compiled out.
 *
 * See the note in Makefile.am, and
 * [[https://bugzilla.gnome.org/show_bug.cgi?id=701099]].
 */
public class FolksTpZeitgeist.Controller : Object
{
  private Zeitgeist.Log? _log = null;
  private Zeitgeist.Monitor? _monitor = null;
  private string _protocol;
  private TelepathyGLib.Account _account;

  /* This object is owned by the PersonaStore, so we don't want a cyclic
   * reference. */
  private unowned PersonaStore _store;

  [CCode (has_target = false)]
  public delegate void IncreasePersonaCounter (Persona p,
      DateTime converted_datetime);

  private IncreasePersonaCounter _im_interaction_cb;
  private IncreasePersonaCounter _last_call_interaction_cb;

  public Controller (PersonaStore store, TelepathyGLib.Account account,
      IncreasePersonaCounter im_interaction_cb,
      IncreasePersonaCounter last_call_interaction_cb)
    {
      this._store = store;
      this._account = account;
      this._protocol = account.protocol_name;
      this._im_interaction_cb = im_interaction_cb;
      this._last_call_interaction_cb = last_call_interaction_cb;
    }

  ~Controller ()
    {
      if (this._monitor != null)
        {
          this._log.remove_monitor (this._monitor);
          this._monitor = null;
        }
    }

  public async void populate_counters ()
    {
      if (this._log == null)
        {
          this._log = new Zeitgeist.Log ();
        }

      /* Get all events for this account from Zeitgeist and increase the
       * the counters of the personas */
      try
        {
          TimeVal tm = TimeVal ();
          int64 end_timestamp = tm.tv_sec;
          /* We want events from the last 30 days only, A day has 86400 seconds.
           * start_timestamp = end_timestamp - 30 days in seconds*/
          int64 start_timestamp = end_timestamp - (86400 * 30);
          GLib.GenericArray<Zeitgeist.Event> events =
              this._get_zeitgeist_event_templates ();
          var results = yield this._log.find_events (
              new TimeRange (start_timestamp * 1000, end_timestamp * 1000),
              events, StorageState.ANY, 0, ResultType.MOST_RECENT_EVENTS,
              null);

          foreach (var e in results)
            {
              var interaction_type = e.get_subject (0).interpretation;
              for (var i = 1; i < e.num_subjects (); i++)
                {
                  var id =
                      this._get_iid_from_event_metadata (e.get_subject (i).uri);
                  if (id == null || interaction_type == null)
                      continue;

                  var persona = this._store.personas.get (id);
                  if (persona == null)
                      continue;

                  persona.freeze_notify ();
                  this._increase_persona_counter (persona, interaction_type, e);
                }
            }

          /* Go back through and thaw notifications. */
          foreach (var e in results)
            {
              var interaction_type = e.get_subject (0).interpretation;
              for (var i = 1; i < e.num_subjects (); i++)
                {
                  var id =
                      this._get_iid_from_event_metadata (e.get_subject (i).uri);
                  if (id == null || interaction_type == null)
                      continue;

                  var persona = this._store.personas.get (id);
                  if (persona == null)
                      continue;

                  persona.thaw_notify ();
                }
            }
        }
      catch
        {
          debug ("Failed to fetch events from Zeitgeist");
        }

      /* Prepare a monitor and install for this account to populate persona
       * counters upon interaction changes.*/
      if (this._monitor == null)
        {
          GLib.GenericArray<Zeitgeist.Event> monitor_events =
              this._get_zeitgeist_event_templates ();
          this._monitor = new Zeitgeist.Monitor (
              new Zeitgeist.TimeRange.from_now (), monitor_events);
          this._monitor.events_inserted.connect (this._handle_new_interaction);
          try
            {
              this._log.install_monitor (this._monitor);
            }
          catch
            {
              warning ("Failed to install monitor for Zeitgeist");
              this._monitor = null;
            }
        }
    }

  private string? _get_iid_from_event_metadata (string? uri)
    {
      /* Format a proper id represting a persona in the store.
       * Zeitgeist uses x-telepathy-identifier as a prefix for telepathy, which
       * is stored as the uri of a subject of an event. */
      if (uri == null)
        {
          return null;
        }
      var new_uri = uri.replace ("x-telepathy-identifier:", "");
      return this._protocol + ":" + new_uri;
    }

  private void _increase_persona_counter (Persona persona,
      string interaction_type, Event event)
    {
      /* Increase the appropriate interaction counter, to signify that an
       * interaction was successfully counted. */
      var timestamp = (uint) (event.timestamp / 1000);
      var converted_datetime = new DateTime.from_unix_utc (timestamp);
      var interpretation = event.interpretation;

      /* Invalid timestamp? Ignore it. */
      if (converted_datetime == null)
          return;

      /* Only count send/receive for IM interactions */
      if (interaction_type == Zeitgeist.NMO.IMMESSAGE &&
          (interpretation == Zeitgeist.ZG.SEND_EVENT ||
           interpretation == Zeitgeist.ZG.RECEIVE_EVENT))
        {
          this._im_interaction_cb (persona, converted_datetime);
        }
      /* Only count successful call for call interactions */
      else if (interaction_type == Zeitgeist.NFO.AUDIO &&
               interpretation == Zeitgeist.ZG.LEAVE_EVENT)
        {
          this._last_call_interaction_cb (persona, converted_datetime);
        }
    }

  private void _handle_new_interaction (TimeRange timerange, ResultSet events)
    {
      foreach (var e in events)
        {
          for (var i = 1; i < e.num_subjects (); i++)
            {
              var id =
                  this._get_iid_from_event_metadata (e.get_subject (i).uri);
              var interaction_type = e.get_subject (0).interpretation;
              if (id == null || interaction_type == null)
                  continue;

              var persona = this._store.personas.get (id);
              if (persona == null)
                  continue;

              this._increase_persona_counter (persona, interaction_type, e);
            }
        }
    }

  private GLib.GenericArray<Zeitgeist.Event> _get_zeitgeist_event_templates ()
    {
      /* To fetch events from Zeitgeist about the interaction with contacts we
       * create templates reflecting how the telepathy-logger stores events in
       * Zeitgeist */
      var origin = "x-telepathy-account-path:" +
          this._account.get_path_suffix ();
      Event ev1 = new Event.full ("", "",
          "dbus://org.freedesktop.Telepathy.Logger.service");
      ev1.origin = origin;
      var templates = new GLib.GenericArray<Zeitgeist.Event> ();
      templates.add (ev1);
      return templates;
    }
}
