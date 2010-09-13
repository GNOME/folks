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
using TelepathyGLib;
using Folks;

public errordomain Tpf.PersonaError
{
  INVALID_ARGUMENT
}

/**
 * A persona subclass which represents a single instant messaging contact from
 * Telepathy.
 */
public class Tpf.Persona : Folks.Persona,
    Alias,
    Avatar,
    Favourite,
    Groups,
    IMable,
    Presence
{
  private HashTable<string, bool> _groups;
  private bool _is_favourite;
  private string _alias;
  private HashTable<string, GenericArray<string>> _im_addresses;

  /* Whether we've finished being constructed; this is used to prevent
   * unnecessary trips to the Telepathy service to tell it about properties
   * being set which are actually just being set from data it's just given us.
   */
  private bool is_constructed = false;

  /**
   * {@inheritDoc}
   */
  public File avatar { get; set; }

  /**
   * {@inheritDoc}
   */
  public Folks.PresenceType presence_type { get; private set; }

  /**
   * {@inheritDoc}
   */
  public string presence_message { get; private set; }

  /**
   * {@inheritDoc}
   */
  public string alias
    {
      get { return this._alias; }

      set
        {
          if (this._alias == value)
            return;

          if (this.is_constructed)
            ((Tpf.PersonaStore) this.store).change_alias (this, value);
          this._alias = value;
        }
    }

  /**
   * {@inheritDoc}
   */
  public bool is_favourite
    {
      get { return this._is_favourite; }

      set
        {
          if (this._is_favourite == value)
            return;

          if (this.is_constructed)
            ((Tpf.PersonaStore) this.store).change_is_favourite (this, value);
          this._is_favourite = value;
        }
    }

  /**
   * {@inheritDoc}
   */
  public HashTable<string, GenericArray<string>> im_addresses
    {
      get { return this._im_addresses; }
      private set {}
    }

  /**
   * {@inheritDoc}
   */
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

          /* Since we're only changing the members of this._groups, rather than
           * replacing it with a new instance, we have to manually emit the
           * notification. */
          this.notify_property ("groups");
        }
    }

  /**
   * {@inheritDoc}
   */
  public async void change_group (string group, bool is_member)
    {
      if (_change_group (group, is_member))
        {
          Tpf.PersonaStore store = (Tpf.PersonaStore) this.store;
          yield store.change_group_membership (this, group, is_member);
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

      if (changed == true)
        this.group_changed (group, is_member);

      return changed;
    }

  /**
   * The Telepathy contact represented by this persona.
   */
  public Contact contact { get; construct; }

  /**
   * Create a new persona.
   *
   * Create a new persona for the {@link PersonaStore} `store`, representing
   * the Telepathy contact given by `contact`.
   */
  public Persona (Contact contact, PersonaStore store) throws Tpf.PersonaError
    {
      string[] linkable_properties = { "im-addresses" };

      /* FIXME: There is the possibility of a crash in the error condition below
       * due to bgo#604299, where the C self variable isn't initialised until we
       * chain up to the Object constructor, below. */
      unowned string id = contact.get_identifier ();
      if (id == null || id == "")
        throw new Tpf.PersonaError.INVALID_ARGUMENT ("contact has an " +
            "invalid ID");

      var account = account_for_connection (contact.get_connection ());
      string uid = this.build_uid ("telepathy", account.get_protocol (), id);

      var alias = contact.get_alias ();
      var display_id = id;

      /* If the alias is empty, fall back to the display ID */
      if (alias == null || alias.strip () == "")
        alias = display_id;

      Object (alias: alias,
              contact: contact,
              display_id: display_id,
              /* FIXME: This IID format should be moved out to the IMable
               * interface along with the code in
               * Kf.Persona.linkable_property_to_links(), but that depends on
               * bgo#624842 being fixed. */
              iid: account.get_protocol () + ":" + id,
              uid: uid,
              store: store,
              linkable_properties: linkable_properties);

      debug ("Creating new Tpf.Persona '%s' for service-specific UID '%s': %p",
          uid, id, this);
      this.is_constructed = true;

      /* Set our single IM address */
      GenericArray<string> im_address_array = new GenericArray<string> ();
      im_address_array.add (IMable.normalise_im_address (id,
          account.get_protocol ()));

      this._im_addresses =
          new HashTable<string, GenericArray<string>> (str_hash, str_equal);
      this._im_addresses.insert (account.get_protocol (), im_address_array);

      /* Groups */
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

      ((Tpf.PersonaStore) this.store).group_members_changed.connect (
          (s, group, added, removed) =>
            {
              if (added.find (this) != null)
                this._change_group (group, true);

              if (removed.find (this) != null)
                this._change_group (group, false);
            });

      ((Tpf.PersonaStore) this.store).group_removed.connect (
          (s, group, error) =>
            {
              /* FIXME: Can't use
               * !(error is TelepathyGLib.DBusError.OBJECT_REMOVED) because the
               * GIR bindings don't annotate errors */
              if (error != null &&
                  (error.domain != TelepathyGLib.dbus_errors_quark () ||
                   error.code != TelepathyGLib.DBusError.OBJECT_REMOVED))
                {
                  debug ("Group invalidated: %s", error.message);
                }

              this._change_group (group, false);
            });
    }

  ~Persona ()
    {
      debug ("Destroying Tpf.Persona '%s': %p", this.uid, this);
    }

  private static Account? account_for_connection (Connection conn)
    {
      var manager = AccountManager.dup ();
      GLib.List<unowned Account> accounts = manager.get_valid_accounts ();

      Account account_found = null;
      accounts.foreach ((l) =>
        {
          unowned Account account = (Account) l;
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
      TelepathyGLib.ConnectionPresenceType type)
    {
      switch (type)
        {
          case TelepathyGLib.ConnectionPresenceType.AVAILABLE:
            return PresenceType.AVAILABLE;
          case TelepathyGLib.ConnectionPresenceType.AWAY:
            return PresenceType.AWAY;
          case TelepathyGLib.ConnectionPresenceType.BUSY:
            return PresenceType.BUSY;
          case TelepathyGLib.ConnectionPresenceType.ERROR:
            return PresenceType.ERROR;
          case TelepathyGLib.ConnectionPresenceType.EXTENDED_AWAY:
            return PresenceType.EXTENDED_AWAY;
          case TelepathyGLib.ConnectionPresenceType.HIDDEN:
            return PresenceType.HIDDEN;
          case TelepathyGLib.ConnectionPresenceType.OFFLINE:
            return PresenceType.OFFLINE;
          case TelepathyGLib.ConnectionPresenceType.UNKNOWN:
            return PresenceType.UNKNOWN;
          case TelepathyGLib.ConnectionPresenceType.UNSET:
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
