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
 */

using BuildConf;
using Folks;

/**
 * A single backend to libfolks, such as Telepathy or evolution-data-server.
 * Each backend provides {@link Persona}s which are aggregated to form
 * {@link Individual}s.
 */
public abstract class Folks.Backend : Object
{
  /**
   * A unique name for the backend.
   *
   * This will be used to identify the backend, and should also be used as the
   * {@link PersonaStore.type_id} of the {@link PersonaStore}s used by the
   * backend.
   */
  public abstract string name { get; protected set; }

  /**
   * The {@link PersonaStore}s in use by the backend.
   *
   * A backend may expose {@link Persona}s from multiple servers or accounts
   * (for example), so may have a {@link PersonaStore} for each.
   */
  public abstract HashTable<string, PersonaStore> persona_stores
    {
      get; protected set;
    }

  /**
   * Emitted when a {@link PersonaStore} is added to the backend.
   *
   * @param store the {@link PersonaStore}
   */
  public abstract signal void persona_store_added (PersonaStore store);

  /**
   * Emitted when a {@link PersonaStore} is removed from the backend.
   *
   * @param store the {@link PersonaStore}
   */
  public abstract signal void persona_store_removed (PersonaStore store);
}
