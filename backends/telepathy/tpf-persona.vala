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
using Tp;
using Folks;

public class Tpf.Persona : Folks.Persona, Alias, Avatar, Folks.Capabilities,
       Groups, Presence, Favourite
{
  private HashTable<string, bool> _groups;
  private bool _is_favourite;

  /* interface Alias */
  public override string alias { get; set; }

  /* interface Avatar */
  public override File avatar { get; set; }

  /* interface Capabilities */
  public override CapabilitiesFlags capabilities { get; private set; }

  /* interface Presence */
  public override Folks.PresenceType presence_type { get; private set; }
  public override string presence_message { get; private set; }

  /* interface Favourite */
  public override bool is_favourite
    {
      get { return this._is_favourite; }

      set
        {
          if (this._is_favourite == value)
            return;

          ((Tpf.PersonaStore) this.store).change_is_favourite (this, value);
          this._is_favourite = value;
        }
    }

  /* interface Groups */
  public HashTable<string, bool> groups
    {
      get { return this._groups; }

      set
        {
          value.foreach ((k, v) =>
            {
              var group = (string) k;
              if (this._groups.lookup (group) == false)
                this._change_group (group, true);
            });

          this._groups.foreach ((k, v) =>
            {
              var group = (string) k;
              if (value.lookup (group) == false)
                this._change_group (group, true);
            });
        }
    }

  public void change_group (string group, bool is_member)
    {
      if (_change_group (group, is_member))
        {
          ((Tpf.PersonaStore) this.store).change_group_membership (this, group,
            is_member);

          this.group_changed (group, is_member);
        }
    }

  private bool _change_group (string group, bool is_member)
    {
      bool changed = false;

      if (is_member)
        {
          if (this._groups.lookup (group) != true)
            {
              this._groups.insert (group, true);
              changed = true;
            }
        }
      else
        changed = this._groups.remove (group);

      return changed;
    }

  public Contact contact { get; construct; }

  public Persona (Contact contact, PersonaStore store) throws Tp.Error
    {
      /* FIXME: There is the possibility of a crash in the error condition below
       * due to bgo#604299, where the C self variable isn't initialised until we
       * chain up to the Object constructor, below. */
      var uid = contact.get_identifier ();
      if (uid == null || uid == "")
        throw new Tp.Error.INVALID_ARGUMENT ("contact has an invalid UID");

      var account = account_for_connection (contact.get_connection ());
      var account_id = ((Proxy) account).object_path;
      /* this isn't meant to convey any real information, so no need to escape
       * existing delimiters */
      var iid = "telepathy:" + account_id + ":" + uid;

      var alias = contact.get_alias ();
      if (alias == null || alias == "")
        alias = uid;

      /* TODO: implement something like Empathy's tp_caps_to_capabilities() and
       * fill in the capabilities as appropriate */
      debug ("capabilities not implemented");

      Object (alias: alias,
              contact: contact,
              iid: iid,
              uid: uid,
              store: store);

      this._groups = new HashTable<string, bool> (str_hash, str_equal);

      contact.notify["avatar-file"].connect ((s, p) =>
        {
          this.contact_notify_avatar ();
        });
      this.contact_notify_avatar ();

      contact.notify["presence-message"].connect ((s, p) =>
        {
          this.contact_notify_presence_message ();
        });
      contact.notify["presence-type"].connect ((s, p) =>
        {
          this.contact_notify_presence_type ();
        });
      this.contact_notify_presence_message ();
      this.contact_notify_presence_type ();

      this.store.group_members_changed.connect ((s, group, added, removed) =>
        {
          if (added.find (this) != null)
            this._change_group (group, true);

          if (removed.find (this) != null)
            this._change_group (group, false);
        });

      this.store.group_removed.connect ((s, group, error) =>
        {
          if (error != null)
            warning ("group invalidated: %s", error.message);

          this._change_group (group, false);
        });
    }

  private static Account? account_for_connection (Connection conn)
    {
      var manager = AccountManager.dup ();
      unowned GLib.List<Account> accounts = manager.get_valid_accounts ();

      Account account_found = null;
      accounts.foreach ((l) =>
        {
          var account = (Account) l;
          if (account.get_connection () == conn)
            {
              account_found = account;
              return;
            }
        });

      return account_found;
    }

  private void contact_notify_presence_message ()
    {
      this.presence_message = this.contact.get_presence_message ();
    }

  private void contact_notify_presence_type ()
    {
      this.presence_type = folks_presence_type_from_tp (
          this.contact.get_presence_type ());
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

  private void contact_notify_avatar ()
    {
      var file = this.contact.get_avatar_file ();
      if (this.avatar != file)
        this.avatar = file;
    }
}
