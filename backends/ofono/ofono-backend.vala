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
 *       Jeremy Whiting <jeremy.whiting@collabora.co.uk>
 *
 * Based on kf-backend.vala by:
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;
using Gee;
using Folks;
using Folks.Backends.Ofono;
using org.ofono;

extern const string BACKEND_NAME;

/**
 * A backend which loads {@link Persona}s from Modem
 * devices using the Ofono Phonebook D-Bus API and presents them
 * using one {@link PersonaStore} per device.
 *
 * @since 0.9.0
 */
public class Folks.Backends.Ofono.Backend : Folks.Backend
{
  private bool _is_prepared = false;
  private bool _prepare_pending = false; /* used for unprepare() too */
  private bool _is_quiescent = false;
  private HashMap<string, PersonaStore> _persona_stores;
  private Map<string, PersonaStore> _persona_stores_ro;
  private ModemProperties[] _modems;

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
  public override void disable_persona_store (Folks.PersonaStore store)
    {
      if (this._persona_stores.has_key (store.id))
        {
          this._store_removed_cb (store);
        }
    }
    
  /**
   * {@inheritDoc}
   */
  public override void enable_persona_store (Folks.PersonaStore store)
    {
      if (this._persona_stores.has_key (store.id) == false)
        {
          this._add_store ((Ofono.PersonaStore) store);
        }
    }
    
  /**
   * {@inheritDoc}
   */
  public override void set_persona_stores (Set<string>? storeids)
    {
      bool added_stores = false;
      PersonaStore[] removed_stores = {};
      
      /* First handle adding any missing persona stores. */
      foreach (ModemProperties modem in this._modems)
        {
          if (modem.path in storeids && 
              this._persona_stores.has_key (modem.path) == false)
            {
              string alias = this._modem_alias (modem.properties);
              PersonaStore store = new Ofono.PersonaStore (modem.path, alias);
              this._add_store (store, false);
              added_stores = true;
            }
        }
      
      foreach (PersonaStore store in this._persona_stores.values)
        {
          if (!storeids.contains (store.id))
            {
              removed_stores += store;
            }
        }
      
      for (int i = 0; i < removed_stores.length; ++i)
        {
          this._remove_store ((Ofono.PersonaStore) removed_stores[i], false);
        }
      
      /* Finally, if anything changed, emit the persona-stores notification. */
      if (added_stores || removed_stores.length > 0)
        {
          this.notify_property ("persona-stores");
        }
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

  private void _add_modem (ObjectPath path, string alias)
    {
      PersonaStore store =
          new Ofono.PersonaStore (path, alias);

      this._add_store (store);
    }

  /**
   * {@inheritDoc}
   */
  public override async void prepare () throws GLib.Error
    {
      Internal.profiling_start ("preparing Ofono.Backend");

      if (this._is_prepared || this._prepare_pending)
        {
          return;
        }

      try
        {
          this._prepare_pending = true;

          /* New modem devices can be caught in notifications */
          Manager manager = yield Bus.get_proxy (BusType.SYSTEM,
                                                       "org.ofono",
                                                       "/");
          manager.ModemAdded.connect (this._modem_added);
          manager.ModemRemoved.connect (this._modem_removed);
          
          this._modems = manager.GetModems ();

          foreach (ModemProperties modem in this._modems)
            {
              this._modem_added (modem.path, modem.properties);
            }

          this.freeze_notify ();
          this._is_prepared = true;
          this.notify_property ("is-prepared");

          this._is_quiescent = true;
          this.notify_property ("is-quiescent");
          this.thaw_notify ();
        }
      finally
        {
          this._prepare_pending = false;
        }

      Internal.profiling_end ("preparing Ofono.Backend");
    }

  /**
   * {@inheritDoc}
   */
  public override async void unprepare () throws GLib.Error
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

          this.freeze_notify ();
          this._persona_stores.clear ();
          this.notify_property ("persona-stores");

          this._is_quiescent = false;
          this.notify_property ("is-quiescent");

          this._is_prepared = false;
          this.notify_property ("is-prepared");
          this.thaw_notify ();
        }
      finally
        {
          this._prepare_pending = false;
        }
    }

  /**
   * Utility function to extract a modem's alias from its properties.
   *
   * @param properties, the properties of the modem.
   * @return the alias to use for this modem.
   */
  private string _modem_alias (HashTable<string, Variant> properties)
    {
      string alias = "";
      
      /* Name is more user friendly than Manufacturer, but both are optional,
       * so use Name if it's there, otherwise Manufacturer, otherwise leave
       * it blank. */
      Variant? name_variant = properties.get ("Name");
      Variant? manufacturer_variant = properties.get ("Manufacturer");
      if (name_variant != null)
        {
          alias = name_variant.get_string ();
        }
      else if (manufacturer_variant != null)
        {
          alias = manufacturer_variant.get_string ();
        }
      return alias;
    }
  
  private void _modem_added (ObjectPath path, HashTable<string, Variant> properties)
    {
      Variant? features_variant = properties.get ("Features");
      if (features_variant != null)
        {
          string alias = this._modem_alias (properties);
          string[] features = features_variant.get_strv ();
          
          foreach (string feature in features)
            {
              if (feature == "sim")
                {
                  /* This modem has a sim card, so add a persona store for it */
                  this._add_modem (path, alias);
                  break;
                }
            }
        }
    }

  /**
   * Utility function to add a persona store.
   *
   * @param store the store to add.
   * @param notify whether or not to emit notification signals.
   */
  private void _add_store (PersonaStore store, bool notify = true)
    {
      this._persona_stores.set (store.id, store);
      store.removed.connect (this._store_removed_cb);
      this.persona_store_added (store);
      if (notify)
        {
          this.notify_property ("persona-stores");
        }
    }
    
  /**
   * Utility function to remove a persona store.
   *
   * @param store the store to remove.
   * @param notify whether or not to emit notification signals.
   */
  private void _remove_store (PersonaStore store, bool notify = true)
    {
      store.removed.disconnect (this._store_removed_cb);
      this._persona_stores.unset (store.id);
      this.persona_store_removed (store);
    
      if (notify)
        {
          this.notify_property ("persona-stores");
        }
    }
    

  private void _modem_removed (ObjectPath path)
    {
      if (this._persona_stores.has_key (path))
        {
          this._store_removed_cb (this._persona_stores.get (path));
        }
    }
    
  private void _store_removed_cb (Folks.PersonaStore store)
    {
      this._remove_store ((Ofono.PersonaStore) store);
    }
}
