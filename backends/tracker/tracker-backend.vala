/*
 * Copyright 2023 Collabora Ltd.
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
 *       Corentin Noël <corentin.noel@collabora.com>
 */

using GLib;
using Gee;
using Folks;

extern const string BACKEND_NAME;

/**
 * A backend which loads {@link Persona}s from paired Bluetooth
 * devices using the Phonebook Access Protocol (PBAP) and presents them
 * using one {@link PersonaStore} per device.
 */
public class Folks.Backends.TrackerBackend : Folks.Backend
{
  private bool _is_prepared = false;
  private bool _prepare_pending = false; /* used for unprepare() too */
  private bool _is_quiescent = false;
  /* Map from PersonaStore.id to PersonaStore. */
  private HashMap<string, PersonaStore> _persona_stores;
  private Map<string, PersonaStore> _persona_stores_ro;
  private Tracker.Sparql.Connection sparql_connection;

  /**
   * Whether this Backend has been prepared.
   *
   * See {@link Folks.Backend.is_prepared}.
   *
   * @since 0.9.6
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * Whether this Backend has reached a quiescent state.
   *
   * See {@link Folks.Backend.is_quiescent}.
   *
   * @since 0.9.6
   */
  public override bool is_quiescent
    {
      get { return this._is_quiescent; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override string name { get { return BACKEND_NAME; } }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override Map<string, Folks.PersonaStore> persona_stores
    {
      get { return this._persona_stores_ro; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override void disable_persona_store (Folks.PersonaStore store)
    {
        //TODO
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override void enable_persona_store (Folks.PersonaStore store)
    {
      // TODO
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override void set_persona_stores (Set<string>? storeids)
    {
      //TODO
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public TrackerBackend ()
    {
      Object ();
    }

  construct
    {
      this._persona_stores = new HashMap<string, PersonaStore> ();
      this._persona_stores_ro = this._persona_stores.read_only_view;
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override async void prepare () throws DBusError
    {
      var profiling = Internal.profiling_start ("preparing Tracker.Backend");

      if (this._is_prepared || this._prepare_pending)
        {
          return;
        }

      _prepare_pending = true;
      this.freeze_notify ();

      Cancellable? cancellable = null;
      try {
          sparql_connection = yield Tracker.Sparql.Connection.bus_new_async ("org.freedesktop.Tracker3.Miner.EDS", null, null, cancellable);
          var cursor = yield sparql_connection.query_async (
            """SELECT ?addressbook ?addressbookName WHERE { ?addressbook a nco:ContactList  .
                OPTIONAL {
                    ?addressbook nie:title ?addressbookName .
                } }""", cancellable);
          while (yield cursor.next_async (cancellable)) {
            long length;
            unowned var addressbook_urn = cursor.get_string (0, out length);
            unowned var title = cursor.get_string (1, out length);
            var store = new TrackerPersonaStore (sparql_connection, addressbook_urn, title);
            _persona_stores.set (store.id, store);
          }
      } catch (Error e) {
        critical (e.message);
      }

      this._is_prepared = true;
      this.notify_property ("is-prepared");

      this._is_quiescent = true;
      this.notify_property ("is-quiescent");

      this.thaw_notify ();
      this._prepare_pending = false;

      Internal.profiling_end ((owned) profiling);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override async void unprepare () throws GLib.Error
    {
      if (!this._is_prepared || this._prepare_pending == true)
        {
          return;
        }

      this._prepare_pending = true;

      this.freeze_notify ();

      //TODO

      this.notify_property ("persona-stores");

      this._is_quiescent = false;
      this.notify_property ("is-quiescent");

      this._is_prepared = false;
      this.notify_property ("is-prepared");

      this.thaw_notify ();
      this._prepare_pending = false;
    }
}

