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
  private bool _prepare_pending = false; /* used by unprepare() too */
  private bool _is_quiescent = false;
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
  public override void enable_persona_store (Folks.PersonaStore store)
    {
      if (this._persona_stores.has_key (store.id) == false)
        {
          this._add_store ((Trf.PersonaStore) store);
        }
    }

  /**
   * {@inheritDoc}
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
   */
  public override void set_persona_stores (Set<string>? storeids)
    {
      if (storeids != null)
        {
          if (storeids.size == 0)
            {
              this.disable_persona_store (this._persona_stores.get (BACKEND_NAME));
            }
          else
            {
              this._add_default_persona_store ();
            }
        }
      else
        {
          this._add_default_persona_store ();
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
   *
   */
  public override async void prepare () throws GLib.Error
    {
      Internal.profiling_start ("preparing Tr.Backend");

      if (this._is_prepared || this._prepare_pending)
        {
          return;
        }

      try
        {
          this._prepare_pending = true;
          this.freeze_notify ();

          this._add_default_persona_store ();

          this._is_prepared = true;
          this.notify_property ("is-prepared");

          this._is_quiescent = true;
          this.notify_property ("is-quiescent");
        }
      finally
        {
          this.thaw_notify ();
          this._prepare_pending = false;
        }

      Internal.profiling_end ("preparing Tr.Backend");
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
          this.freeze_notify ();

          foreach (var persona_store in this._persona_stores.values)
            {
             this.persona_store_removed (persona_store);
            }

          this._persona_stores.clear ();
          this.notify_property ("persona-stores");

          this._is_quiescent = false;
          this.notify_property ("is-quiescent");

          this._is_prepared = false;
          this.notify_property ("is-prepared");
        }
      finally
        {
          this.thaw_notify ();
          this._prepare_pending = false;
        }
    }

  /**
   * Add a the default Persona Store.
   */
  private void _add_default_persona_store ()
    {
      if (this._persona_stores.has_key (BACKEND_NAME) == false)
        {
          var store = new Trf.PersonaStore ();
          this._add_store (store);
        }
    }

  /**
   * Utility function to add a persona store.
   *
   * @param store the store to add.
   * @param notify whether or not to emit notification signals.
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

  private void _store_removed_cb (Folks.PersonaStore store)
    {
      store.removed.disconnect (this._store_removed_cb);
      this.persona_store_removed (store);
      this._persona_stores.unset (store.id);
    }
}
