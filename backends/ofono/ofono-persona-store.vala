/*
 * Copyright (C) 2012 Collabora Ltd.
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
 *          Jeremy Whiting <jeremy.whiting@collabora.co.uk>
 *
 * Based on kf-persona-store.vala by:
 *       Travis Reitter <travis.reitter@collabora.co.uk>
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;
using Gee;
using Folks;
using Folks.Backends.Ofono;

/**
 * A persona store which is associated with a single Ofono device. It will
 * create a {@link Persona} for each contact on the SIM card phonebook.
 *
 * @since 0.9.0
 */
public class Folks.Backends.Ofono.PersonaStore : Folks.PersonaStore
{
  private HashMap<string, Persona> _personas;
  private Map<string, Persona> _personas_ro;
  private bool _is_prepared = false;
  private bool _prepare_pending = false;
  private bool _is_quiescent = false;

  private static string[] _always_writeable_properties = {};
  private ObjectPath? _path = null;

  private org.ofono.Phonebook? _ofono_phonebook = null;

  /**
   * {@inheritDoc}
   */
  public override string type_id { get { return BACKEND_NAME; } }

  /**
   * {@inheritDoc}
   */
  public override MaybeBool can_add_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * {@inheritDoc}
   */
  public override MaybeBool can_alias_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * {@inheritDoc}
   */
  public override MaybeBool can_group_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * {@inheritDoc}
   */
  public override MaybeBool can_remove_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * {@inheritDoc}
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * {@inheritDoc}
   */
  public override bool is_quiescent
    {
      get { return this._is_quiescent; }
    }

  /**
   * {@inheritDoc}
   */
  public override string[] always_writeable_properties
    {
      get { return Ofono.PersonaStore._always_writeable_properties; }
    }

  /**
   * {@inheritDoc}
   */
  public override Map<string, Folks.Persona> personas
    {
      get { return this._personas_ro; }
    }

  /**
   * Create a new PersonaStore.
   *
   * Create a new persona store to expose the {@link Persona}s provided by the
   * modem with the given address.
   *
   * @param path the D-Bus object path of this modem
   * @param alias the name this modem should display to users
   *
   * @since 0.9.0
   */
  public PersonaStore (ObjectPath path, string alias)
    {
      Object (id: path,
              display_name: alias);

      this.trust_level = PersonaStoreTrust.FULL;
      this._personas = new HashMap<string, Persona> ();
      this._personas_ro = this._personas.read_only_view;
      this._path = path;
    }

  private void _property_changed (string property, Variant value)
    {
      if (property == "Present" && value.get_boolean () == false)
        {
          this._remove_self ();
        }
    }

  private void _remove_self ()
    {
      /* Marshal the personas from a Collection to a Set. */
      var removed_personas = new HashSet<Persona> ();
      var iter = this._personas.map_iterator ();

      while (iter.next () == true)
      {
        removed_personas.add (iter.get_value ());
      }

      this._emit_personas_changed (null, removed_personas);
      this.removed ();
    }

  private string[] _split_all_vcards (string all_vcards)
    {
      /* Ofono vcards are in vcard 3.0 format and can include the following:
       * FN, CATEGORIES, EMAIL and IMPP fields. */
      string[] lines = all_vcards.split ("\n");
      string[] vcards = {};
      string vcard = "";

      foreach (string line in lines)
        {
          /* Skip whitespace between vCards. */
          if (vcard == "" && line.strip () == "")
              continue;

          vcard += line;
          vcard += "\n";

          if (line.strip () == "END:VCARD")
            {
              vcards += vcard;
              vcard = "";
            }
        }

      return vcards;
    }

  /**
   * {@inheritDoc}
   */
  public override async void prepare () throws IOError, DBusError
    {
      var profiling = Internal.profiling_start ("preparing Ofono.PersonaStore (ID: %s)",
          this.id);

      if (this._is_prepared || this._prepare_pending)
        {
          return;
        }

      try
        {
          this._prepare_pending = true;
          this._ofono_phonebook = yield Bus.get_proxy (BusType.SYSTEM,
                                                             "org.ofono",
                                                             this._path);

          org.ofono.SimManager sim_manager = yield Bus.get_proxy (BusType.SYSTEM,
                                                                        "org.ofono",
                                                                        this._path);
          sim_manager.PropertyChanged.connect (this._property_changed);

          string all_vcards = this._ofono_phonebook.Import ();

          string[] vcards = this._split_all_vcards (all_vcards);

          HashSet<Persona> added_personas = new HashSet<Persona> ();

          foreach (string vcard in vcards)
            {
              Persona persona = new Persona (vcard, this);
              this._personas.set (persona.iid, persona);
              added_personas.add (persona);
            }

          if (this._personas.size > 0)
            {
              this._emit_personas_changed (added_personas, null);
            }
        }
      catch (GLib.DBusError e)
        {
          warning ("DBus Error has occurred when fetching ofono phonebook, %s", e.message);
          this._remove_self ();
        }
      catch (GLib.IOError e)
        {
          warning ("IO Error has occurred when fetching ofono phonebook, %s", e.message);
          this._remove_self ();
        }
      finally
        {
          this._is_prepared = true;
          this.notify_property ("is-prepared");

          /* We've finished loading all the personas we know about */
          this._is_quiescent = true;
          this.notify_property ("is-quiescent");

          this._prepare_pending = false;
        }

      Internal.profiling_end ((owned) profiling);
    }

  /**
   * Remove a {@link Persona} from the PersonaStore.
   *
   * See {@link Folks.PersonaStore.remove_persona}.
   *
   * @throws Folks.PersonaStoreError.READ_ONLY every time since the
   * Ofono backend is read-only.
   *
   * @param persona the {@link Persona} to remove.
   *
   * @since 0.9.0
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
   * @throws Folks.PersonaStoreError.READ_ONLY every time since the
   * Ofono backend is read-only.
   *
   * @param details the details of the {@link Persona} to add.
   *
   * @since 0.9.0
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      throw new PersonaStoreError.READ_ONLY (
          "Personas cannot be added to this store.");
    }
}
