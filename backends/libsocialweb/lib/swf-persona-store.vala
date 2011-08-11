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
using Gee;
using Folks;
using SocialWebClient;

extern const string BACKEND_NAME;

/**
 * A persona store which is associated with a single libsocialweb service.
 * It will create {@link Persona}s for each of the contacts known to that
 * service.
 */
public class Swf.PersonaStore : Folks.PersonaStore
{
  private HashMap<string, Persona> _personas;
  private Map<string, Persona> _personas_ro;
  private bool _is_prepared = false;
  private ClientService _service;
  private ClientContactView _contact_view;

  /* No writeable properties
   *
   * FIXME: we can't mark this as const because Vala gets confused
   *        and generates the wrong C output (char *arr[0] = {}
   *        instead of char **arr = NULL)
   */
  private static string[] _always_writeable_properties = {};

  /**
   * The type of persona store this is.
   *
   * See {@link Folks.PersonaStore.type_id}.
   */
  public override string type_id { get { return BACKEND_NAME; } }

  /**
   * Whether this PersonaStore can add {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_add_personas}.
   *
   * @since 0.5.0
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
   * @since 0.5.0
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
   * @since 0.5.0
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
   * @since 0.5.0
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
   * @since 0.5.0
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public override string[] always_writeable_properties
    {
      get { return this._always_writeable_properties; }
    }
  /**
   * The {@link Persona}s exposed by this PersonaStore.
   *
   * See {@link Folks.PersonaStore.personas}.
   */
  public override Map<string, Persona> personas
    {
      get { return this._personas_ro; }
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
      this._personas = new HashMap<string, Persona> ();
      this._personas_ro = this._personas.read_only_view;
    }

  ~PersonaStore ()
    {
      if (this._contact_view != null)
        {
          this._contact_view.contacts_added.disconnect (this.contacts_added_cb);
          this._contact_view.contacts_changed.disconnect (
              this.contacts_changed_cb);
          this._contact_view.contacts_removed.disconnect (
              this.contacts_removed_cb);
        }
    }

  /**
   * Add a new {@link Persona} to the PersonaStore.
   *
   * See {@link Folks.PersonaStore.add_persona_from_details}.
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      throw new PersonaStoreError.READ_ONLY (
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
      throw new PersonaStoreError.READ_ONLY (
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
              this._service.get_static_capabilities (
                  (service, caps, error) =>
                    {
                      if (caps == null)
                        return;

                      bool has_contacts = ClientService.has_cap (caps,
                          "has-contacts-query-iface");
                      if (!has_contacts)
                        return;
                      var parameters = new HashTable<weak string, weak string>
                          (str_hash, str_equal);
                      this._service.contacts_query_open_view
                          ("people", parameters, (query, contact_view) =>
                        {
                          /* The D-Bus call could return an error. In this
                           * case, contact_view is null */
                          if (contact_view == null)
                            return;

                          contact_view.contacts_added.connect
                              (this.contacts_added_cb);
                          contact_view.contacts_changed.connect
                              (this.contacts_changed_cb);
                          contact_view.contacts_removed.connect
                              (this.contacts_removed_cb);

                          this._contact_view = contact_view;
                          this._is_prepared = true;
                          this.notify_property ("is-prepared");

                          this._contact_view.start ();
                        });
                    });
            }
        }
    }

  private void contacts_added_cb (GLib.List<unowned Contact> contacts)
    {
      var added_personas = new HashSet<Persona> ();
      foreach (var contact in contacts)
        {
          var persona = new Persona(this, contact);
          _personas.set (persona.iid, persona);
          added_personas.add (persona);
        }

      if (added_personas.size > 0)
        {
          this._emit_personas_changed (added_personas, null);
        }
    }

  private void contacts_changed_cb (GLib.List<unowned Contact> contacts)
    {
      foreach (var contact in contacts)
        {
          if (this._service.get_name () != contact.service)
            {
              continue;
            }
          var iid = Swf.Persona._build_iid(contact.service, Persona.get_contact_id (contact));
          var persona = _personas.get (iid);
          if (persona != null)
            persona.update (contact);
        }
    }

  private void contacts_removed_cb (GLib.List<unowned Contact> contacts)
    {
      var removed_personas = new HashSet<Persona> ();
      foreach (var contact in contacts)
        {
          if (this._service.get_name () != contact.service)
            {
              continue;
            }
          var iid = Swf.Persona._build_iid(contact.service, Persona.get_contact_id (contact));
          var persona = _personas.get (iid);
          if (persona != null)
            {
              removed_personas.add (persona);
              _personas.unset (persona.iid);
            }
        }

      if (removed_personas.size > 0)
        {
          this._emit_personas_changed (null, removed_personas);
        }
    }
}
