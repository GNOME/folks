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

/**
 * Errors from {@link PersonaStore}s.
 */
public errordomain Folks.PersonaStoreError
{
  /**
   * An argument to the method was invalid.
   */
  INVALID_ARGUMENT,

  /**
   * Creation of a {@link Persona} failed.
   */
  CREATE_FAILED,
}

/**
 * A store for {@link Persona}s.
 */
public abstract class Folks.PersonaStore : Object
{
  /**
   * Emitted when one or more {@link Persona}s are added to the PersonaStore.
   *
   * @param personas a list of {@link Persona}s added to the PersonaStore
   */
  public abstract signal void personas_added (GLib.List<Persona> personas);

  /**
   * Emitted when one or more {@link Persona}s are removed from the
   * PersonaStore.
   *
   * @param personas a list of {@link Persona}s removed from the PersonaStore
   */
  public abstract signal void personas_removed (GLib.List<Persona> personas);

  /**
   * Emitted when {@link Persona}s within the PersonaStore are added to or
   * removed from a group.
   *
   * @param group a freeform identifier for the group
   * @param added a list of {@link Persona}s added to `group`
   * @param removed a list of {@link Persona}s removed from `group`
   */
  public abstract signal void group_members_changed (string group,
      GLib.List<Persona>? added, GLib.List<Persona>? removed);

  /**
   * Emitted when a group is removed.
   *
   * @param group a freeform identifier for the group being removed
   * @param error non-`null` if there was an error when removing the group
   */
  public abstract signal void group_removed (string group, GLib.Error? error);

  /* the backing store itself was deleted and its personas are now invalid */
  /**
   * Emitted when the backing store for this PersonaStore has been removed.
   *
   * At this point, the PersonaStore and all its {@link Persona}s are invalid,
   * so any client referencing it should unreference it.
   */
  public abstract signal void removed ();

  /**
   * The type of PersonaStore this is.
   *
   * This is the same for all PersonaStores provided by a given {@link Backend}.
   */
  public abstract string type_id { get; protected set; }

  /**
   * The instance identifier for this PersonaStore.
   *
   * Since each {@link Backend} can provide multiple different PersonaStores
   * for different accounts or servers (for example), they each need an ID
   * which is unique within the backend.
   */
  public abstract string id { get; protected set; }

  /**
   * The {@link Persona}s exposed by this PersonaStore.
   */
  public abstract HashTable<string, Persona> personas { get; }

  /**
   * Add or remove a {@link Persona} within the PersonaStore from a group.
   *
   * Change the `persona`'s membership status of the group given by the freeform
   * group ID `group`.
   *
   * @param persona the {@link Persona} within the PersonaStore to change
   * @param group a freeform group identifier
   * @param is_member `true` if the {@link Persona} should be made a member of
   * `group`, `false` otherwise
   */
  public abstract async void change_group_membership (Persona persona,
      string group, bool is_member);

  /**
   * Add a new {@link Persona} to the PersonaStore.
   *
   * The {@link Persona} will be created by the PersonaStore backend from the
   * key-value pairs given in `details`. FIXME: These are backend-specific.
   *
   * If the details are not recognised or are invalid,
   * {@link PersonaStoreError.INVALID_ARGUMENT} will be thrown.
   *
   * @param details a key-value map of details to use in creating the new
   * {@link Persona}
   * @return the new {@link Persona}, or `null` on failure
   */
  public abstract async Persona? add_persona_from_details (
      HashTable<string, string> details) throws Folks.PersonaStoreError;

  /**
   * Remove a {@link Persona} from the PersonaStore.
   *
   * @param persona the {@link Persona} to remove
   */
  public abstract void remove_persona (Persona persona);
}
