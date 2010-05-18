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

using Gee;
using GLib;
using Folks.Alias;
using Folks.Capabilities;
using Folks.PersonaStore;
using Folks.Presence;

public class Folks.Individual : Object, Alias, Capabilities, Presence
{
  private GLib.List<Persona> _personas;
  private HashTable<PersonaStore, HashSet<Persona>> stores;

  /* XXX: should setting this push it down into the Persona (to foward along to
   * the actual store if possible?) */
  public string alias { get; set; }
  public CapabilitiesFlags capabilities { get; private set; }
  public Folks.PresenceType presence_type { get; private set; }
  public string presence_message { get; private set; }

  /* the last of this individuals personas has been removed, so it is invalid */
  public signal void removed ();

  public GLib.List<Persona> personas
    {
      get { return this._personas; }

      set
        {
          this._personas.foreach ((p) =>
            {
              var persona = (Persona) p;

              persona.notify["presence-message"].disconnect (
                  this.notify_presence_cb);
              persona.notify["presence-type"].disconnect (
                  this.notify_presence_cb);
            });

          this._personas = value.copy ();

          this._personas.foreach ((p) =>
            {
              var persona = (Persona) p;

              persona.notify["presence-message"].connect (
                  this.notify_presence_cb);
              persona.notify["presence-type"].connect (this.notify_presence_cb);
            });

          this.update_fields ();
        }
    }

  private void notify_presence_cb (Object obj, ParamSpec ps)
    {
      this.update_presence ();
    }

  public Individual (GLib.List<Persona>? personas)
    {
      Object (personas: personas);

      this.stores = new HashTable<PersonaStore, HashSet<Persona>> (direct_hash,
          direct_equal);
      this.stores_update ();
    }

  private void stores_update ()
    {
      this._personas.foreach ((p) =>
        {
          var persona = (Persona) p;
          var store_is_new = false;
          var persona_set = this.stores.lookup (persona.store);
          if (persona_set == null)
            {
              persona_set = new HashSet<Persona> (direct_hash, direct_equal);
              store_is_new = true;
            }

          persona_set.add (persona);

          if (store_is_new)
            {
              this.stores.insert (persona.store, persona_set);

              persona.store.removed.connect (this.store_removed_cb);
            }
        });
    }

  private void store_removed_cb (PersonaStore store)
    {
      var persona_set = this.stores.lookup (store);

      foreach (var persona in persona_set)
        {
          this._personas.remove (persona);
        }

      if (persona_set.size < 1)
        this.stores.remove (store);

      if (this._personas.length () < 1)
        {
          this.removed ();
          return;
        }

      this.update_fields ();
    }

  private void update_fields ()
    {
      var old_alias = this.alias;
      var old_caps = this.capabilities;

      /* gather the first occurence of each field */
      string alias = null;
      var caps = CapabilitiesFlags.NONE;
      this._personas.foreach ((persona) =>
        {
          var p = (Persona) persona;

          /* FIXME: also check to see if alias is just whitespace */
          if (alias == null)
            alias = p.alias;

          caps |= p.capabilities;
        });

      if (alias == null)
        {
          /* FIXME: pick a UID or similar instead */
          alias = "Name Unknown";
        }

      /* only notify if the value has changed */
      if (alias != old_alias)
        this.alias = alias;

      if (caps != old_caps)
        this.capabilities = caps;

      this.update_presence ();
    }

  private void update_presence ()
    {
      var old_presence_message = this.presence_message;
      var old_presence_type = this.presence_type;
      var presence_message = "";
      var presence_type = Folks.PresenceType.UNSET;
      this._personas.foreach ((persona) =>
        {
          var p = (Persona) persona;

          if (presence_message == null || presence_message == "")
            presence_message = p.presence_message;

          if (Presence.typecmp (p.presence_type, presence_type) > 0)
            presence_type = p.presence_type;
        });

      if (presence_message == null)
        presence_message = "";

      /* only notify if the value has changed */
      if (presence_message != old_presence_message)
        this.presence_message = presence_message;

      if (presence_type != old_presence_type)
        this.presence_type = presence_type;
    }

  public CapabilitiesFlags get_capabilities ()
    {
      return this.capabilities;
    }

  /*
   * GLib/C convenience functions (for built-in casting, etc.)
   */
  public unowned string get_alias ()
    {
      return this.alias;
    }

  public string get_presence_message ()
    {
      return this.presence_message;
    }

  public Folks.PresenceType get_presence_type ()
    {
      return this.presence_type;
    }

  public bool is_online ()
    {
      Presence p = this;
      return p.is_online ();
    }
}
