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
using Folks.Alias;

public class Folks.Individual : Object, Alias
{
  private GLib.List<Persona> _personas;

  /* XXX: should setting this push it down into the Persona (to foward along to
   * the actual store if possible?) */
  public string alias { get; set; }

  /* FIXME: set up specific functions, so we can update the alias, etc.
    * cache before notifying any users about the change
    *
    * make the custom getters/setters work on _personas
    */
  public GLib.List<Persona> personas
    {
      get { return this._personas; }

      set
        {
          this._personas = value.copy ();
          this.update_fields ();
        }
    }

  public Individual (GLib.List<Persona>? personas)
    {
      Object (personas: personas);
    }

  private void update_fields ()
    {
      /* gather the first occurence of each field */
      string alias = null;
      this._personas.foreach ((persona) =>
        {
          var p = (Persona) persona;

          /* FIXME: also check to see if alias is just whitespace */
          if (alias == null)
            alias = p.alias;
        });

      if (alias == null)
        {
          /* FIXME: pick a UID or similar instead */
          alias = "Name Unknown";
        }

      /* write them back to the local members */
      this.alias = alias;
    }
}
