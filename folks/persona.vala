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
using Folks.Capabilities;
using Folks.Presence;

public abstract class Folks.Persona : Object, Alias, Capabilities, Presence
{
  /* interface Alias */
  public abstract string alias { get; set; }

  /* interface Capabilities */
  public abstract CapabilitiesFlags capabilities { get; set; }

  /* interface Presence */
  public abstract Folks.PresenceType presence_type { get; set; }
  public abstract string presence_message { get; set; }

  /* internal ID */
  public string iid { get; construct; }
  /* universal ID (eg, "foo@xmpp.example.org") */
  public string uid { get; construct; }
}
