/*
 * Copyright 2023 Collabora Ltd.
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
 *       Corentin Noël <corentin.noel@collabora.com>
 */

using GLib;
using Gee;
using Folks;

/**
 * A persona store which is associated with a single BlueZ PBAP server (i.e.
 * one {@link PersonaStore} per device). It will create a {@link Persona} for
 * each contact on the device.
 *
 * Since large contact lists can take a long time to download in full (on the
 * order of 1s per 10 contacts), contacts are downloaded in two phases:
 * # Phase 1 downloads all non-PHOTO data. This is very fast (on the order of
 * 1s per 400 contacts)
 * # Phase 2 downloads all PHOTO data for those contacts. This is slow, but
 * happens later, in the background.
 *
 * Subsequent download attempts happen on an exponentially increasing interval,
 * up to a limit (once this limit is reached, updates occur on a regular
 * interval; the linear region). Download attempts repeat indefinitely unless a
 * certain number of consecutive attempts end in failure. See the documentation
 * for {@link _schedule_update_contacts} for details.
 *
 * @since 0.9.6
 */
public class Folks.Backends.TrackerPersonaStore : Folks.PersonaStore
{
  private HashMap<string, TrackerPersona> _personas;
  private Map<string, TrackerPersona> _personas_ro;
  private bool _is_prepared = false;
  private bool _prepare_pending = false;
  private bool _is_quiescent = false;
  private Tracker.Sparql.Connection sparql_connection;

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override string type_id { get { return BACKEND_NAME; } }

  /**
   * Whether this PersonaStore can add {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_add_personas}.
   *
   * @since 0.9.6
   */
  public override MaybeBool can_add_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore can set the alias of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_alias_personas}.
   *
   * @since 0.9.6
   */
  public override MaybeBool can_alias_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore can set the groups of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_group_personas}.
   *
   * @since 0.9.6
   */
  public override MaybeBool can_group_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore can remove {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_remove_personas}.
   *
   * @since 0.9.6
   */
  public override MaybeBool can_remove_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore has been prepared.
   *
   * See {@link Folks.PersonaStore.is_prepared}.
   *
   * @since 0.9.6
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * Whether this PersonaStore has reached a quiescent state.
   *
   * See {@link Folks.PersonaStore.is_quiescent}.
   *
   * @since 0.9.6
   */
  public override bool is_quiescent
    {
      get { return this._is_quiescent; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  private class string[] _always_writeable_properties = {};
  public override string[] always_writeable_properties
    {
      get { return this._always_writeable_properties; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override Map<string, Folks.Persona> personas
    {
      get { return this._personas_ro; }
    }

  /**
   * Create a new PersonaStore.
   *
   * Create a new persona store to expose the {@link Persona}s provided by the
   * addressbook with the given urn.
   *
   * @param sparql_connection the Sparql connection
   * @param addressbook_urn the URN of the addressbook
   *
   * @since 0.9.6
   */
  public TrackerPersonaStore (Tracker.Sparql.Connection sparql_connection, string addressbook_urn, string? title)
    {
      Object (id: addressbook_urn, display_name: title);
      this.sparql_connection = sparql_connection;
    }

  construct
    {
      this._personas = new HashMap<string, TrackerPersona> ();
      this._personas_ro = this._personas.read_only_view;
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override async void prepare () throws PersonaStoreError
    {
      var profiling = Internal.profiling_start ("preparing Tracker.PersonaStore (ID: %s)",
          this.id);

      if (this._is_prepared || this._prepare_pending)
        {
          return;
        }

      try
        {
          this._prepare_pending = true;

          var added_personas = new HashSet<Persona> ();
          var cursor = yield sparql_connection.query_async (
            """SELECT ?contact ?contactUID ?contactFullname {
                <%s> nco:containsContact ?contact .
                ?contact nco:contactUID ?contactUID .
                ?contact nco:fullname ?contactFullname
            }""".printf (id), null);
          while (yield cursor.next_async (null)) {
            long length;
            unowned var contact_urn = cursor.get_string (0, out length);
            unowned var contact_uid = cursor.get_string (1, out length);
            unowned var contact_fullname = cursor.get_string (2, out length);
            var persona = new TrackerPersona (sparql_connection, this, contact_urn, contact_uid, contact_fullname);
            _personas.set (persona.iid, persona);
            added_personas.add (persona);
          }

        if (added_personas.is_empty == false)
        {
          this._emit_personas_changed (added_personas, null);
        }

          this._is_prepared = true;
          this.notify_property ("is-prepared");

          this._is_quiescent = true;
          this.notify_property ("is-quiescent");
        }
      catch (Error e)
        {
          critical (e.message);
        }
      finally
        {
          this._prepare_pending = false;
        }

      Internal.profiling_end ((owned) profiling);
    }

  /**
   * Remove a {@link Persona} from the PersonaStore.
   *
   * See {@link Folks.PersonaStore.remove_persona}.
   *
   * @param persona the {@link Persona} to remove
   * @throws Folks.PersonaStoreError.READ_ONLY every time since the
   * Tracker backend is read-only.
   *
   * @since 0.9.6
   */
  public override async void remove_persona (Folks.Persona persona)
      throws Folks.PersonaStoreError
    {
      throw new PersonaStoreError.READ_ONLY (
          "Personas cannot be removed from this store.");
    }

  /**
   * Add a new {@link Persona} to the PersonaStore.
   *
   * See {@link Folks.PersonaStore.add_persona_from_details}.
   *
   * @param details a map of keys to values giving the persona’s initial details
   * @throws Folks.PersonaStoreError.READ_ONLY every time since the
   * Tracker backend is read-only.
   *
   * @since 0.9.6
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      throw new PersonaStoreError.READ_ONLY (
          "Personas cannot be added to this store.");
    }
}
