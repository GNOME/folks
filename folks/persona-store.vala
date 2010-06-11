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

using GLib;
using Folks;

public abstract class Folks.PersonaStore : Object
{
  public abstract signal void personas_added (GLib.List<Persona> personas);
  public abstract signal void personas_removed (GLib.List<Persona> personas);
  public abstract signal void group_members_changed (string group,
      GLib.List<Persona>? added, GLib.List<Persona>? removed);
  public abstract signal void group_removed (string group, GLib.Error? error);

  /* the backing store itself was deleted and its personas are now invalid */
  public abstract signal void removed ();

  public abstract string type_id { get; protected set; }
  public abstract string id { get; protected set; }
  public abstract HashTable<string, Persona> personas { get; }

  public abstract async void change_group_membership (Persona persona,
      string group, bool is_member);
}
