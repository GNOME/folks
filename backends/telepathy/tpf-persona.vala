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

errordomain Tpf.PersonaError
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
    Folks.Capabilities,
    Favourite,
    Groups,
    Presence
{
  private HashTable<string, bool> _groups;
  private bool _is_favourite;
  private string _alias;

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
  public CapabilitiesFlags capabilities { get; private set; }

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

  /**
   * {@inheritDoc}
   */
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
      /* FIXME: There is the possibility of a crash in the error condition below
       * due to bgo#604299, where the C self variable isn't initialised until we
       * chain up to the Object constructor, below. */
      var uid = contact.get_identifier ();
      if (uid == null || uid == "")
        throw new Tpf.PersonaError.INVALID_ARGUMENT ("contact has an " +
            "invalid UID");

      var account = account_for_connection (contact.get_connection ());
      var account_id = ((Proxy) account).object_path;
      /* this isn't meant to convey any real information, so no need to escape
       * existing delimiters */
      var iid = "telepathy:" + account_id + ":" + uid;

      var alias = contact.get_alias ();
      if (alias == null || alias.strip () == "")
        alias = uid;

      Object (alias: alias,
              contact: contact,
              iid: iid,
              uid: uid,
              store: store);

      this.is_constructed = true;

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

      contact.notify["capabilities"].connect ((s, p) =>
        {
          this.contact_notify_capabilities ();
        });
      this.contact_notify_capabilities ();

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
              if (error != null)
                warning ("group invalidated: %s", error.message);

              this._change_group (group, false);
            });
    }

  private static Account? account_for_connection (Connection conn)
    {
      var manager = AccountManager.dup ();
      GLib.List<Account> accounts = manager.get_valid_accounts ();

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

  private void contact_notify_capabilities ()
    {
      var caps = this.contact.get_capabilities ();
      if (caps != null)
        this.capabilities = folks_capabilities_flags_from_tp (caps);
    }

  /* Based off tp_caps_to_capabilities() in empathy-contact.c */
  private static CapabilitiesFlags folks_capabilities_flags_from_tp (
      TelepathyGLib.Capabilities caps)
    {
      CapabilitiesFlags capabilities = 0;
      var classes = caps.get_channel_classes ();

      classes.foreach ((m) =>
        {
          unowned ValueArray class_struct = (ValueArray) m;

          unowned Value val = class_struct.get_nth (0);
          unowned HashTable fixed_prop = (HashTable) val.get_boxed ();

          TelepathyGLib.HandleType handle_type =
              (TelepathyGLib.HandleType) TelepathyGLib.asv_get_uint32 (
                  fixed_prop, TelepathyGLib.PROP_CHANNEL_TARGET_HANDLE_TYPE,
                  null);
          if (handle_type != HandleType.CONTACT)
            return; /* i.e. continue the loop */

          unowned string chan_type = TelepathyGLib.asv_get_string (fixed_prop,
              TelepathyGLib.PROP_CHANNEL_CHANNEL_TYPE);

          if (chan_type == TelepathyGLib.IFACE_CHANNEL_TYPE_FILE_TRANSFER)
            {
              capabilities |= CapabilitiesFlags.FILE_TRANSFER;
            }
          else if (chan_type == TelepathyGLib.IFACE_CHANNEL_TYPE_STREAM_TUBE)
            {
              var service = TelepathyGLib.asv_get_string (fixed_prop,
                  TelepathyGLib.PROP_CHANNEL_TYPE_STREAM_TUBE_SERVICE);

              if (service == "rfb")
                capabilities |= CapabilitiesFlags.STREAM_TUBE;
            }
          else if (chan_type == TelepathyGLib.IFACE_CHANNEL_TYPE_STREAMED_MEDIA)
            {
              val = class_struct.get_nth (1);
              unowned string[] allowed_prop = (string[]) val.get_boxed ();

              if (allowed_prop != null)
                {
                  for (int i = 0; allowed_prop[i] != null; i++)
                    {
                      unowned string prop = allowed_prop[i];

                      if (prop ==
                          TelepathyGLib.PROP_CHANNEL_TYPE_STREAMED_MEDIA_INITIAL_AUDIO)
                        capabilities |= CapabilitiesFlags.AUDIO;
                      else if (prop ==
                          TelepathyGLib.PROP_CHANNEL_TYPE_STREAMED_MEDIA_INITIAL_VIDEO)
                        capabilities |= CapabilitiesFlags.VIDEO;
                    }
                }
            }
        });

      return capabilities;
    }
}
