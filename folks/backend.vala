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

public abstract class Folks.Backend : Object
{
  public abstract string name { get; protected set; }
  public abstract HashTable<string, PersonaStore> persona_stores
    {
      get; protected set;
    }

  public abstract signal void persona_store_added (PersonaStore store);
  public abstract signal void persona_store_removed (PersonaStore store);
}
