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
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 *       Marco Barisione <marco.barisione@collabora.co.uk>
 */

using GLib;
using Folks;
using SocialWebClient;

/**
 * A persona store which is associated with a single libsocialweb service.
 * It will create {@link Persona}s for each of the contacts known to that
 * service.
 */
public class Folks.Backends.Sw.PersonaStore : Folks.PersonaStore
{
  private HashTable<string, Persona> _personas;
  private bool _is_prepared = false;
  private ClientService _service;
  private ClientItemView _item_view;

  /**
   * The type of persona store this is.
   *
   * See {@link Folks.PersonaStore.type_id}.
   */
  public override string type_id { get { return "libsocialweb"; } }

  /**
   * Whether this PersonaStore can add {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_add_personas}.
   *
   * @since 0.3.1
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
   * @since 0.3.1
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
   * @since 0.3.1
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
   * @since 0.3.1
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
   * @since 0.3.0
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * The {@link Persona}s exposed by this PersonaStore.
   *
   * See {@link Folks.PersonaStore.personas}.
   */
  public override HashTable<string, Persona> personas
    {
      get { return this._personas; }
    }

  /**
   * Create a new PersonaStore.
   *
   * Create a new persona store to store the {@link Persona}s for the contacts
   * provided by the `service`.
   */
  public PersonaStore (ClientService service)
    {
      Object (display_name: service.get_display_name(),
              id: service.get_name ());

      this.trust_level = PersonaStoreTrust.PARTIAL;
      this._service = service;
      this._personas = new HashTable<string, Persona> (str_hash, str_equal);
    }

  /**
   * Add a new {@link Persona} to the PersonaStore.
   *
   * See {@link Folks.PersonaStore.add_persona_from_details}.
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      // FIXME: There is no better error for this.
      throw new PersonaStoreError.UNSUPPORTED_ON_USER (
          "Personas cannot be added to this store.");
    }

  /**
   * Remove a {@link Persona} from the PersonaStore.
   *
   * See {@link Folks.PersonaStore.remove_persona}.
   */
  public override async void remove_persona (Folks.Persona persona)
      throws Folks.PersonaStoreError
    {
      // FIXME: There is no better error for this.
      throw new PersonaStoreError.UNSUPPORTED_ON_USER (
          "Personas cannot be removed from this store.");
    }

  /**
   * Prepare the PersonaStore for use.
   *
   * See {@link Folks.PersonaStore.prepare}.
   */
  public override async void prepare ()
    {
      lock (this._is_prepared)
        {
          if (!this._is_prepared)
            {
              var parameters = new HashTable<weak string, weak string> (
                  str_hash, str_equal);
              this._service.query_open_view("people", parameters,
                  (query, item_view) =>
                    {
                      item_view.items_added.connect (this.items_added_cb);
                      item_view.items_changed.connect (this.items_changed_cb);
                      item_view.items_removed.connect (this.items_removed_cb);

                      this._item_view = item_view;
                      this._is_prepared = true;
                      this.notify_property ("is-prepared");

                      this._item_view.start ();
                    });
            }
        }
    }

  private void items_added_cb (List<unowned Item> items)
    {
      var added_personas = new Queue<Persona> ();
      foreach (var item in items)
        {
          var persona = new Persona(this, item);
          _personas.insert(persona.iid, persona);
          added_personas.push_tail(persona);
        }

      if (added_personas.length > 0)
        this.personas_changed (added_personas.head, null, null, null, 0);
    }

  private void items_changed_cb (List<unowned Item> items)
    {
      foreach (var item in items)
        {
          var persona = _personas.lookup(Persona.get_item_id (item));
          if (persona != null)
            persona.update (item);
        }
    }

  private void items_removed_cb (List<unowned Item> items)
    {
      var removed_personas = new Queue<Persona> ();
      foreach (var item in items)
        {
          var persona = _personas.lookup(Persona.get_item_id (item));
          if (persona != null)
            {
              removed_personas.push_tail(persona);
              _personas.remove(persona.iid);
            }
        }

      if (removed_personas.length > 0)
        this.personas_changed (null, removed_personas.head, null, null, 0);
    }

}
