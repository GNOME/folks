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
using Folks;
using Folks.Backends.Kf;

/**
 * A backend which loads {@link Persona}s from a simple key file in
 * (XDG_DATA_HOME/folks/) and presents them through a single
 * {@link PersonaStore}.
 *
 * @since 0.1.13
 */
public class Folks.Backends.Kf.Backend : Folks.Backend
{
  /**
   * {@inheritDoc}
   */
  public override string name { get; private set; }

  /**
   * {@inheritDoc}
   */
  public override HashTable<string, PersonaStore> persona_stores
    {
      get; private set;
    }

  /**
   * {@inheritDoc}
   */
  public Backend ()
    {
      Object (name: "key-file");
    }

  /**
   * {@inheritDoc}
   */
  public override async void prepare () throws GLib.Error
    {
      File file;
      string path = Environment.get_variable ("FOLKS_BACKEND_KEY_FILE_PATH");
      if (path == null)
        {
          file = File.new_for_path (Environment.get_user_data_dir ());
          file = file.get_child ("folks");
          file = file.get_child ("relationships.ini");

          debug ("Using built-in key file '%s' (override with environment " +
              "variable FOLKS_BACKEND_KEY_FILE_PATH)", file.get_path ());
        }
      else
        {
          file = File.new_for_path (path);
          debug ("Using environment variable FOLKS_BACKEND_KEY_FILE_PATH = '%s'"
              + " to load the key file.", path);
        }

      /* Create the PersonaStore for the key file */
      PersonaStore store = new Kf.PersonaStore (file);

      this.persona_stores.insert (store.id, store);
      store.removed.connect (this.store_removed_cb);

      this.persona_store_added (store);
    }

  private void store_removed_cb (Folks.PersonaStore store)
    {
      this.persona_store_removed (store);
      this.persona_stores.remove (store.id);
    }
}
