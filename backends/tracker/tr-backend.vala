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
 * Authors:
 *       Travis Reitter <travis.reitter@collabora.co.uk>
 *       Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 */

using Folks;
using Folks.Backends.Tr;
using GLib;
using Gee;

extern const string BACKEND_NAME;

/**
 * A backend which connects to Tracker and creates a {@link PersonaStore}
 * for each service.
 */
public class Folks.Backends.Tr.Backend : Folks.Backend
{
  private bool _is_prepared = false;
  private HashMap<string, PersonaStore> _persona_stores;

  /**
   * {@inheritDoc}
   */
  public override string name { get { return BACKEND_NAME; } }

  /**
   * {@inheritDoc}
   */
  public override Map<string, PersonaStore> persona_stores
    {
      get { return this._persona_stores; }
    }

  /**
   * {@inheritDoc}
   */
  public Backend ()
    {
      this._persona_stores = new HashMap<string, PersonaStore> ();
    }

  /**
   * Whether this Backend has been prepared.
   *
   * See {@link Folks.Backend.is_prepared}.
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * {@inheritDoc}
   *
   */
  public override async void prepare () throws GLib.Error
    {
      lock (this._is_prepared)
        {
          if (!this._is_prepared)
            {
              this._add_default_persona_store ();
              this._is_prepared = true;
              this.notify_property ("is-prepared");
            }
        }
    }

  /**
   * {@inheritDoc}
   */
  public override async void unprepare () throws GLib.Error
    {
      foreach (var persona_store in this._persona_stores.values)
        {
          this.persona_store_removed (persona_store);
        }

      this._persona_stores.clear ();
      this.notify_property ("persona-stores");

      this._is_prepared = false;
      this.notify_property ("is-prepared");
    }

  /**
   * Add a the default Persona Store.
   */
  private void _add_default_persona_store ()
    {
      var store = new Trf.PersonaStore ();
      this._persona_stores.set (store.id, store);
      store.removed.connect (this._store_removed_cb);
      this.notify_property ("persona-stores");
      this.persona_store_added (store);
    }

  private void _store_removed_cb (Folks.PersonaStore store)
    {
      store.removed.disconnect (this._store_removed_cb);
      this.persona_store_removed (store);
      this.persona_stores.unset (store.id);
    }
}
