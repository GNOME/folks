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
 *       Travis Reitter <travis.reitter@collabora.co.uk>
 *       Marco Barisione <marco.barisione@collabora.co.uk>
 */

using GLib;
using Gee;
using Folks;
using Folks.Backends.Sw;
using SocialWebClient;

extern const string BACKEND_NAME;

/**
 * A backend which connects to libsocialweb and creates a {@link PersonaStore}
 * for each service.
 */
public class Folks.Backends.Sw.Backend : Folks.Backend
{
  private bool _is_prepared = false;
  private Client _client;
  private HashMap<string, PersonaStore> _persona_stores;
  private Map<string, PersonaStore> _persona_stores_ro;

  /**
   * {@inheritDoc}
   */
  public override string name { get { return BACKEND_NAME; } }

  /**
   * {@inheritDoc}
   */
  public override Map<string, PersonaStore> persona_stores
    {
      get { return this._persona_stores_ro; }
    }


  /**
   * {@inheritDoc}
   */
  public Backend ()
    {
      this._persona_stores = new HashMap<string, PersonaStore> ();
      this._persona_stores_ro = this._persona_stores.read_only_view;
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
   */
  public override async void prepare () throws GLib.Error
    {
      lock (this._is_prepared)
        {
          if (!this._is_prepared)
            {
              this._client = new Client();
              this._client.get_services((client, services) =>
                {
                  foreach (var service_name in services)
                    this.add_service (service_name);

                  this._is_prepared = true;
                  this.notify_property ("is-prepared");
                });
            }
        }
    }

  /**
   * {@inheritDoc}
   */
  public override async void unprepare () throws GLib.Error
    {
      foreach (var store in this._persona_stores.values)
        {
          store.removed.disconnect (this.store_removed_cb);
          this.persona_store_removed (store);
        }

      this._client = null;

      this._persona_stores.clear ();
      this.notify_property ("persona-stores");

      this._is_prepared = false;
      this.notify_property ("is-prepared");
    }

  private void add_service (string service_name)
    {
      if (this._persona_stores.get (service_name) != null)
        return;

      var store = new Swf.PersonaStore (this._client.get_service (service_name));
      this._persona_stores.set (store.id, store);
      store.removed.connect (this.store_removed_cb);
      this.persona_store_added (store);
    }

  private void store_removed_cb (Folks.PersonaStore store)
    {
      this.persona_store_removed (store);
      this._persona_stores.unset (store.id);
    }
}
