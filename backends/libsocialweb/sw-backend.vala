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
  private bool _prepare_pending = false;
  private bool _is_quiescent = false;
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
   *
   * @since 0.9.0
   */
  public override void enable_persona_store (Folks.PersonaStore store)
    {
      if (this._persona_stores.has_key (store.id) == false)
        {
          this._add_store ((Swf.PersonaStore) store);
        }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.0
   */
  public override void disable_persona_store (Folks.PersonaStore store)
    {
      if (this._persona_stores.has_key (store.id))
        {
          this._store_removed_cb (store);
        }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.0
   */
  public override void set_persona_stores (Set<string>? storeids)
    {
      /* All ids represent ini files in user_data_dir/folks/ */

      bool added_stores = false;
      PersonaStore[] removed_stores = {};

      /* First handle adding any missing persona stores. */
      foreach (string id in storeids)
        {
          if (this._persona_stores.has_key (id) == false)
            {
              ClientService service = this._client.get_service (id);
              var store = new Swf.PersonaStore (service);
              this._add_store (store, false);
              added_stores = true;
            }
        }

      foreach (PersonaStore store in this._persona_stores.values)
        {
          if (!storeids.contains (store.id))
            {
              removed_stores += store;
            }
        }

      foreach (var store in removed_stores)
        {
          this._remove_store ((Swf.PersonaStore) store, false);
        }

      /* Finally, if anything changed, emit the persona-stores notification. */
      if (added_stores || removed_stores.length > 0)
        {
          this.notify_property ("persona-stores");
        }
    }

  /**
   * {@inheritDoc}
   */
  public Backend ()
    {
      Object ();
    }

  construct
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
   * Whether this Backend has reached a quiescent state.
   *
   * See {@link Folks.Backend.is_quiescent}.
   *
   * @since 0.6.2
   */
  public override bool is_quiescent
    {
      get { return this._is_quiescent; }
    }

  /**
   * {@inheritDoc}
   */
  public override async void prepare () throws GLib.Error
    {
      Internal.profiling_start ("preparing Sw.Backend");

      if (this._is_prepared || this._prepare_pending)
        {
          return;
        }

      /* Hold a ref. on the Backend while we wait for the callback from
       * this._client.get_services() to prevent the Backend being
       * destroyed in the mean time. See: bgo#665039. */
      this.ref ();

      this._prepare_pending = true;

      this._client = new Client ();
      this._client.get_services((client, services) =>
        {
          try
            {
              foreach (var service_name in services)
                this.add_service (service_name);

              this._is_prepared = true;
              this.notify_property ("is-prepared");

              this._is_quiescent = true;
              this.notify_property ("is-quiescent");

              this.unref ();
            }
          finally
            {
              this._prepare_pending = false;
            }
        });

      Internal.profiling_end ("preparing Sw.Backend");
    }

  /**
   * {@inheritDoc}
   */
  public override async void unprepare () throws GLib.Error
    {
      if (!this._is_prepared || this._prepare_pending)
        {
          return;
        }

      try
        {
          this._prepare_pending = true;

          foreach (var store in this._persona_stores.values)
            {
              store.removed.disconnect (this._store_removed_cb);
              this.persona_store_removed (store);
            }

          this._client = null;

          this._persona_stores.clear ();
          this.notify_property ("persona-stores");

          this._is_quiescent = false;
          this.notify_property ("is-quiescent");

          this._is_prepared = false;
          this.notify_property ("is-prepared");
        }
      finally
        {
          this._prepare_pending = false;
        }
    }

  /**
   * Utility function to add a persona store.
   *
   * @param store the store to add.
   * @param notify whether or not to emit notification signals.
   * @since 0.9.0
   */
  private void _add_store (PersonaStore store, bool notify = true)
    {
      this._persona_stores.set (store.id, store);
      store.removed.connect (this._store_removed_cb);
      this.persona_store_added (store);
      if (notify)
        {
          this.notify_property ("persona-stores");
        }
    }

  /**
   * Utility function to remove a persona store.
   *
   * @param store the store to remove.
   * @param notify whether or not to emit notification signals.
   * @since 0.9.0
   */
  private void _remove_store (PersonaStore store, bool notify = true)
    {
      store.removed.disconnect (this._store_removed_cb);
      this._persona_stores.unset (store.id);
      this.persona_store_removed (store);

      if (notify)
        {
          this.notify_property ("persona-stores");
        }
    }

  private void add_service (string service_name)
    {
      if (this._persona_stores.get (service_name) != null)
        return;

      var store = new Swf.PersonaStore (this._client.get_service (service_name));
      this._add_store (store);
    }

  private void _store_removed_cb (Folks.PersonaStore store)
    {
      this._remove_store ((Swf.PersonaStore) store);
    }
}
