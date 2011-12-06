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
using Folks;
using Folks.Backends.Kf;

extern const string BACKEND_NAME;

/**
 * A backend which loads {@link Persona}s from a simple key file in
 * (XDG_DATA_HOME/folks/) and presents them through a single
 * {@link PersonaStore}.
 *
 * @since 0.1.13
 */
public class Folks.Backends.Kf.Backend : Folks.Backend
{
  private bool _is_prepared = false;
  private bool _prepare_pending = false; /* used for unprepare() too */
  private bool _is_quiescent = false;
  private HashMap<string, PersonaStore> _persona_stores;
  private Map<string, PersonaStore> _persona_stores_ro;

  /**
   * Whether this Backend has been prepared.
   *
   * See {@link Folks.Backend.is_prepared}.
   *
   * @since 0.3.0
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
      Object ();
    }

  construct
    {
      this._persona_stores = new HashMap<string, PersonaStore> ();
      this._persona_stores_ro = this._persona_stores.read_only_view;
    }

  /**
   * {@inheritDoc}
   */
  public override async void prepare () throws GLib.Error
    {
      lock (this._is_prepared)
        {
          if (this._is_prepared || this._prepare_pending)
            {
              return;
            }

          try
            {
              this._prepare_pending = true;

              File file;
              unowned string path = Environment.get_variable (
                  "FOLKS_BACKEND_KEY_FILE_PATH");
              if (path == null)
                {
                  file = File.new_for_path (Environment.get_user_data_dir ());
                  file = file.get_child ("folks");
                  file = file.get_child ("relationships.ini");

                  debug ("Using built-in key file '%s' (override with " +
                      "environment variable FOLKS_BACKEND_KEY_FILE_PATH)",
                      file.get_path ());
                }
              else
                {
                  file = File.new_for_path (path);
                  debug ("Using environment variable " +
                      "FOLKS_BACKEND_KEY_FILE_PATH = '%s' to load the key " +
                      "file.", path);
                }

              /* Create the PersonaStore for the key file */
              PersonaStore store = new Kf.PersonaStore (file);

              this._persona_stores.set (store.id, store);
              store.removed.connect (this._store_removed_cb);
              this.notify_property ("persona-stores");

              this.persona_store_added (store);

              this._is_prepared = true;
              this.notify_property ("is-prepared");

              this._is_quiescent = true;
              this.notify_property ("is-quiescent");
            }
          finally
            {
              this._prepare_pending = false;
            }
        }
    }

  /**
   * {@inheritDoc}
   */
  public override async void unprepare () throws GLib.Error
    {
      lock (this._is_prepared)
        {
          if (!this._is_prepared || this._prepare_pending == true)
            {
              return;
            }

          try
            {
              this._prepare_pending = true;

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
              this._prepare_pending = false;
            }
        }
    }

  private void _store_removed_cb (Folks.PersonaStore store)
    {
      store.removed.disconnect (this._store_removed_cb);
      this.persona_store_removed (store);
      this._persona_stores.unset (store.id);
      this.notify_property ("persona-stores");
    }
}
