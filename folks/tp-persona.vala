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
using Tp;
using Folks.Alias;
using Folks.Capabilities;
using Folks.Persona;
using Folks.Presence;

public class Folks.TpPersona : Persona, Alias, Capabilities, Presence
{
  /* interface Alias */
  public override string alias { get; set; }

  /* interface Capabilities */
  public override CapabilitiesFlags capabilities { get; private set; }

  /* interface Presence */
  public override Folks.PresenceType presence_type { get; private set; }
  public override string presence_message { get; private set; }

  public Contact contact { get; construct; }

  public TpPersona (Contact contact, PersonaStore store)
    {
      var uid = contact.get_identifier ();
      if (uid == null || uid == "")
        {
          /* FIXME: throw an exception */
        }

      var alias = contact.get_alias ();
      if (alias == null || alias == "")
        alias = uid;

      /* TODO: implement something like Empathy's tp_caps_to_capabilities() and
       * fill in the capabilities as appropriate */
      debug ("capabilities not implemented");

      Object (alias: alias,
              contact: contact,
              /* FIXME: we'll probably need to include the ID for the contact's
               * account in the iid */
              iid: uid,
              uid: uid,
              store: store);

      contact.notify["presence-message"].connect ((s, p) =>
        {
          this.contact_notify_presence_message ((Tp.Contact) s);
        });
      contact.notify["presence-type"].connect ((s, p) =>
        {
          this.contact_notify_presence_type ((Tp.Contact) s);
        });
      this.contact_notify_presence_message (contact);
      this.contact_notify_presence_type (contact);
    }

  private void contact_notify_presence_message (Tp.Contact contact)
    {
      this.presence_message = contact.get_presence_message ();
    }

  private void contact_notify_presence_type (Tp.Contact contact)
    {
      this.presence_type = folks_presence_type_from_tp (
          contact.get_presence_type ());
    }

  private static PresenceType folks_presence_type_from_tp (
      Tp.ConnectionPresenceType type)
    {
      switch (type)
        {
          case Tp.ConnectionPresenceType.AVAILABLE:
            return PresenceType.AVAILABLE;
          case Tp.ConnectionPresenceType.AWAY:
            return PresenceType.AWAY;
          case Tp.ConnectionPresenceType.BUSY:
            return PresenceType.BUSY;
          case Tp.ConnectionPresenceType.ERROR:
            return PresenceType.ERROR;
          case Tp.ConnectionPresenceType.EXTENDED_AWAY:
            return PresenceType.EXTENDED_AWAY;
          case Tp.ConnectionPresenceType.HIDDEN:
            return PresenceType.HIDDEN;
          case Tp.ConnectionPresenceType.OFFLINE:
            return PresenceType.OFFLINE;
          case Tp.ConnectionPresenceType.UNKNOWN:
            return PresenceType.UNKNOWN;
          case Tp.ConnectionPresenceType.UNSET:
            return PresenceType.UNSET;
          default:
            return PresenceType.UNKNOWN;
        }
    }
}
