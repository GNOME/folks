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

/**
 * A persona subclass which represents a single instant messaging contact from
 * Telepathy.
 */
public class Tpf.Persona : Folks.Persona,
    Aliasable,
    Favouritable,
    Groupable,
    HasAvatar,
    HasPresence,
    IMable
{
  private HashTable<string, bool> _groups;
  private bool _is_favourite;
  private string _alias;
  private HashTable<string, LinkedHashSet<string>> _im_addresses;
  private const string[] _linkable_properties = { "im-addresses" };

  /* Whether we've finished being constructed; this is used to prevent
   * unnecessary trips to the Telepathy service to tell it about properties
   * being set which are actually just being set from data it's just given us.
   */
  private bool _is_constructed = false;

  /**
   * An avatar for the Persona.
   *
   * See {@link Folks.HasAvatar.avatar}.
   */
  public File avatar { get; set; }

  /**
   * The Persona's presence type.
   *
   * See {@link Folks.HasPresence.presence_type}.
   */
  public Folks.PresenceType presence_type { get; private set; }

  /**
   * The Persona's presence message.
   *
   * See {@link Folks.HasPresence.presence_message}.
   */
  public string presence_message { get; private set; }

  /**
   * The names of the Persona's linkable properties.
   *
   * See {@link Folks.Persona.linkable_properties}.
   */
  public override string[] linkable_properties
    {
      get { return this._linkable_properties; }
    }

  /**
   * An alias for the Persona.
   *
   * See {@link Folks.Aliasable.alias}.
   */
  public string alias
    {
      get { return this._alias; }

      set
        {
          if (this._alias == value)
            return;

          if (this._is_constructed)
            ((Tpf.PersonaStore) this.store).change_alias (this, value);
          this._alias = value;
        }
    }

  /**
   * Whether this Persona is a user-defined favourite.
   *
   * See {@link Folks.Favouritable.is_favourite}.
   */
  public bool is_favourite
    {
      get { return this._is_favourite; }

      set
        {
          if (this._is_favourite == value)
            return;

          if (this._is_constructed)
            ((Tpf.PersonaStore) this.store).change_is_favourite (this, value);
          this._is_favourite = value;
        }
    }

  /**
   * A mapping of IM protocol to an ordered set of IM addresses.
   *
   * See {@link Folks.IMable.im_addresses}.
   */
  public HashTable<string, LinkedHashSet<string>> im_addresses
    {
      get { return this._im_addresses; }
      private set {}
    }

  /**
   * A mapping of group ID to whether the contact is a member.
   *
   * See {@link Folks.Groupable.groups}.
   */
  public HashTable<string, bool> groups
    {
      get { return this._groups; }

      set
        {
          value.foreach ((k, v) =>
            {
              unowned string group = (string) k;
              if (this._groups.lookup (group) == false)
                this._change_group (group, true);
            });

          this._groups.foreach ((k, v) =>
            {
              unowned string group = (string) k;
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
   * Add or remove the Persona from the specified group.
   *
   * See {@link Folks.Groupable.change_group}.
   */
  public async void change_group (string group, bool is_member)
    {
      if (this._change_group (group, is_member))
        {
          Tpf.PersonaStore store = (Tpf.PersonaStore) this.store;
          yield store._change_group_membership (this, group, is_member);
        }
    }

  private bool _change_group (string group, bool is_member)
    {
      var changed = false;

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
   *
   * @param contact the Telepathy contact being represented by the persona
   * @param store the persona store to place the persona in
   */
  public Persona (Contact contact, PersonaStore store)
    {
      unowned string id = contact.get_identifier ();
      unowned Connection connection = contact.connection;
      var account = this._account_for_connection (connection);
      var uid = this.build_uid (store.type_id, account.get_protocol (), id);

      Object (alias: contact.get_alias (),
              contact: contact,
              display_id: id,
              /* FIXME: This IID format should be moved out to the IMable
               * interface along with the code in
               * Kf.Persona.linkable_property_to_links(), but that depends on
               * bgo#624842 being fixed. */
              iid: account.get_protocol () + ":" + id,
              uid: uid,
              store: store,
              is_user: contact.handle == connection.self_handle);

      contact.notify["alias"].connect ((s, p) =>
          {
            if (this._alias != contact.alias)
              {
                this._alias = contact.alias;
                this.notify_property ("alias");
              }
          });

      debug ("Creating new Tpf.Persona '%s' for service-specific UID '%s': %p",
          uid, id, this);
      this._is_constructed = true;

      /* Set our single IM address */
      LinkedHashSet<string> im_address_set = new LinkedHashSet<string> ();
      try
        {
          im_address_set.add (IMable.normalise_im_address (id,
              account.get_protocol ()));
        }
      catch (IMableError e)
        {
          /* This should never happen…but if it does, warn of it and continue */
          warning (e.message);
        }

      this._im_addresses =
          new HashTable<string, LinkedHashSet<string>> (str_hash, str_equal);
      this._im_addresses.insert (account.get_protocol (), im_address_set);

      /* Groups */
      this._groups = new HashTable<string, bool> (str_hash, str_equal);

      contact.notify["avatar-file"].connect ((s, p) =>
        {
          this._contact_notify_avatar ();
        });
      this._contact_notify_avatar ();

      contact.notify["presence-message"].connect ((s, p) =>
        {
          this._contact_notify_presence_message ();
        });
      contact.notify["presence-type"].connect ((s, p) =>
        {
          this._contact_notify_presence_type ();
        });
      this._contact_notify_presence_message ();
      this._contact_notify_presence_type ();

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

  private static Account? _account_for_connection (Connection conn)
    {
      var manager = AccountManager.dup ();
      var accounts = manager.get_valid_accounts ();

      Account account_found = null;
      accounts.foreach ((l) =>
        {
          unowned Account account = (Account) l;
          if (account.connection == conn)
            {
              account_found = account;
              return;
            }
        });

      return account_found;
    }

  private void _contact_notify_presence_message ()
    {
      this.presence_message = this.contact.get_presence_message ();
    }

  private void _contact_notify_presence_type ()
    {
      this.presence_type = Tpf.Persona._folks_presence_type_from_tp (
          this.contact.get_presence_type ());
    }

  private static PresenceType _folks_presence_type_from_tp (
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

  private void _contact_notify_avatar ()
    {
      var file = this.contact.avatar_file;
      if (this.avatar != file)
        this.avatar = file;
    }
}
