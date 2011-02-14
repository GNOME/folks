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
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;
using Gee;
using TelepathyGLib;
using Folks;

extern const string BACKEND_NAME;

/**
 * A persona store which is associated with a single Telepathy account. It will
 * create {@link Persona}s for each of the contacts in the published, stored or
 * subscribed
 * [[http://people.collabora.co.uk/~danni/telepathy-book/chapter.channel.html|channels]]
 * of the account.
 */
public class Tpf.PersonaStore : Folks.PersonaStore
{
  /* FIXME: expose the interface strings in the introspected tp-glib bindings
   */
  private static string _tp_channel_iface = "org.freedesktop.Telepathy.Channel";
  private static string _tp_channel_contact_list_type = _tp_channel_iface +
      ".Type.ContactList";
  private static string _tp_channel_channel_type = _tp_channel_iface +
      ".ChannelType";
  private static string _tp_channel_handle_type = _tp_channel_iface +
      ".TargetHandleType";
  private static string[] _undisplayed_groups =
      {
        "publish",
        "stored",
        "subscribe"
      };
  private static ContactFeature[] _contact_features =
      {
        ContactFeature.ALIAS,
        ContactFeature.AVATAR_DATA,
        ContactFeature.AVATAR_TOKEN,
        ContactFeature.CAPABILITIES,
        ContactFeature.CLIENT_TYPES,
        ContactFeature.PRESENCE
      };

  private HashTable<string, Persona> _personas;
  /* universal, contact owner handles (not channel-specific) */
  private HashMap<uint, Persona> _handle_persona_map;
  private HashMap<Channel, HashSet<Persona>> _channel_group_personas_map;
  private HashMap<Channel, HashSet<uint>> _channel_group_incoming_adds;
  private HashMap<string, HashSet<Tpf.Persona>> _group_outgoing_adds;
  private HashMap<string, HashSet<Tpf.Persona>> _group_outgoing_removes;
  private HashMap<string, Channel> _standard_channels_unready;
  private HashMap<string, Channel> _group_channels_unready;
  private HashMap<string, Channel> _groups;
  /* FIXME: Should be HashSet<Handle> */
  private HashSet<uint> _favourite_handles;
  private Channel _publish;
  private Channel _stored;
  private Channel _subscribe;
  private Connection _conn;
  private TpLowlevel _ll;
  private AccountManager _account_manager;
  private Logger _logger;
  private Contact _self_contact;
  private MaybeBool _can_add_personas = MaybeBool.UNSET;
  private MaybeBool _can_alias_personas = MaybeBool.UNSET;
  private MaybeBool _can_group_personas = MaybeBool.UNSET;
  private MaybeBool _can_remove_personas = MaybeBool.UNSET;
  private bool _is_prepared = false;

  internal signal void group_members_changed (string group,
      GLib.List<Persona>? added, GLib.List<Persona>? removed);
  internal signal void group_removed (string group, GLib.Error? error);

  /**
   * The Telepathy account this store is based upon.
   */
  [Property(nick = "basis account",
      blurb = "Telepathy account this store is based upon")]
  public Account account { get; construct; }

  /**
   * The type of persona store this is.
   *
   * See {@link Folks.PersonaStore.type_id}.
   */
  public override string type_id { get { return BACKEND_NAME; } }

  /**
   * Whether this PersonaStore can add {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_add_personas}.
   *
   * @since 0.3.1
   */
  public override MaybeBool can_add_personas
    {
      get { return this._can_add_personas; }
    }

  /**
   * Whether this PersonaStore can set the alias of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_alias_personas}.
   *
   * @since 0.3.1
   */
  public override MaybeBool can_alias_personas
    {
      get { return this._can_alias_personas; }
    }

  /**
   * Whether this PersonaStore can set the groups of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_group_personas}.
   *
   * @since 0.3.1
   */
  public override MaybeBool can_group_personas
    {
      get { return this._can_group_personas; }
    }

  /**
   * Whether this PersonaStore can remove {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_remove_personas}.
   *
   * @since 0.3.1
   */
  public override MaybeBool can_remove_personas
    {
      get { return this._can_remove_personas; }
    }

  /**
   * Whether this PersonaStore has been prepared.
   *
   * See {@link Folks.PersonaStore.is_prepared}.
   *
   * @since 0.3.0
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * The {@link Persona}s exposed by this PersonaStore.
   *
   * See {@link Folks.PersonaStore.personas}.
   */
  public override HashTable<string, Persona> personas
    {
      get { return this._personas; }
    }

  /**
   * Create a new PersonaStore.
   *
   * Create a new persona store to store the {@link Persona}s for the contacts
   * in the Telepathy account provided by `account`.
   *
   * @param account the Telepathy account being represented by the persona store
   */
  public PersonaStore (Account account)
    {
      Object (account: account,
              display_name: account.display_name,
              id: account.get_object_path ());

      this._reset ();
    }

  private void _reset ()
    {
      /* We do not trust local-xmpp or IRC at all, since Persona UIDs can be
       * faked by just changing hostname/username or nickname. */
      if (account.get_protocol () == "local-xmpp" ||
          account.get_protocol () == "irc")
        this.trust_level = PersonaStoreTrust.NONE;
      else
        this.trust_level = PersonaStoreTrust.PARTIAL;

      this._personas = new HashTable<string, Persona> (str_hash,
          str_equal);
      this._conn = null;
      this._handle_persona_map = new HashMap<uint, Persona> ();
      this._channel_group_personas_map =
          new HashMap<Channel, HashSet<Persona>> ();
      this._channel_group_incoming_adds =
          new HashMap<Channel, HashSet<uint>> ();
      this._group_outgoing_adds = new HashMap<string, HashSet<Tpf.Persona>> ();
      this._group_outgoing_removes = new HashMap<string, HashSet<Tpf.Persona>> (
          );
      this._publish = null;
      this._stored = null;
      this._subscribe = null;
      this._standard_channels_unready = new HashMap<string, Channel> ();
      this._group_channels_unready = new HashMap<string, Channel> ();
      this._groups = new HashMap<string, Channel> ();
      this._favourite_handles = new HashSet<uint> ();
      this._ll = new TpLowlevel ();
    }

  /**
   * Prepare the PersonaStore for use.
   *
   * See {@link Folks.PersonaStore.prepare}.
   */
  public override async void prepare ()
    {
      lock (this._is_prepared)
        {
          if (!this._is_prepared)
            {
              this._account_manager = AccountManager.dup ();

              this._account_manager.account_disabled.connect ((a) =>
                {
                  if (this.account == a)
                    {
                      this.personas_changed (null, this._personas.get_values (),
                        null, null, 0);
                      this.removed ();
                    }
                });
              this._account_manager.account_removed.connect ((a) =>
                {
                  if (this.account == a)
                    {
                      this.personas_changed (null, this._personas.get_values (),
                        null, null, 0);
                      this.removed ();
                    }
                });
              this._account_manager.account_validity_changed.connect (
                  (a, valid) =>
                    {
                      if (!valid && this.account == a)
                        {
                          this.personas_changed (null, this._personas.get_values
                            (), null, null, 0);
                          this.removed ();
                        }
                    });

              this.account.status_changed.connect (
                  this._account_status_changed_cb);

              TelepathyGLib.ConnectionStatusReason reason;
              var status = this.account.get_connection_status (out reason);
              /* immediately handle accounts which are not currently being
               * disconnected */
              if (status != TelepathyGLib.ConnectionStatus.DISCONNECTED)
                {
                  this._account_status_changed_cb (
                      TelepathyGLib.ConnectionStatus.DISCONNECTED, status,
                      reason, null, null);
                }

              try
                {
                  this._logger = new Logger (this.id);
                  this._logger.invalidated.connect (() =>
                    {
                      warning (
                          _("Lost connection to the telepathy-logger service."));
                      this._logger = null;
                    });
                  this._logger.favourite_contacts_changed.connect (
                      this._favourite_contacts_changed_cb);
                }
              catch (DBus.Error e)
                {
                  warning (
                      _("Couldn't connect to the telepathy-logger service."));
                  this._logger = null;
                }

              this._is_prepared = true;
              this.notify_property ("is-prepared");
            }
        }
    }

  private async void _initialise_favourite_contacts ()
    {
      if (this._logger == null)
        return;

      /* Get an initial set of favourite contacts */
      try
        {
          var contacts = yield this._logger.get_favourite_contacts ();

          if (contacts.length == 0)
            return;

          /* Note that we don't need to release these handles, as they're
           * also held by the relevant contact objects, and will be released
           * as appropriate by those objects (we're circumventing tp-glib's
           * handle reference counting). */
          this._conn.request_handles (-1, HandleType.CONTACT, contacts,
            (c, ht, h, i, e, w) =>
              {
                try
                  {
                    this._change_favourites_by_request_handles ((Handle[]) h, i,
                        e, true);
                  }
                catch (GLib.Error e)
                  {
                    /* Translators: the parameter is an error message. */
                    warning (_("Couldn't get list of favorite contacts: %s"),
                        e.message);
                  }
              },
            this);
          /* FIXME: Have to pass this as weak_object parameter since Vala
           * seems to swap the order of user_data and weak_object in the
           * callback. */
        }
      catch (DBus.Error e)
        {
          /* Translators: the parameter is an error message. */
          warning (_("Couldn't get list of favorite contacts: %s"), e.message);
        }
    }

  private void _change_favourites_by_request_handles (Handle[] handles,
      string[] ids, GLib.Error? error, bool add) throws GLib.Error
    {
      if (error != null)
        throw error;

      for (var i = 0; i < handles.length; i++)
        {
          var h = handles[i];
          var p = this._handle_persona_map[h];

          /* Add/Remove the handle to the set of favourite handles, since we
           * might not have the corresponding contact yet */
          if (add)
            this._favourite_handles.add (h);
          else
            this._favourite_handles.remove (h);

          /* If the persona isn't in the _handle_persona_map yet, it's most
           * likely because the account hasn't connected yet (and we haven't
           * received the roster). If there are already entries in
           * _handle_persona_map, the account *is* connected and we should
           * warn about the unknown persona.
           * We have to take into account that this._self_contact may be
           * retrieved before or after the rest of the account's contact list,
           * affecting the size of this._handle_persona_map. */
          if (p == null &&
              ((this._self_contact == null &&
                this._handle_persona_map.size > 0) ||
               (this._self_contact != null &&
                    this._handle_persona_map.size > 1)))
            {
              /* Translators: the parameter is an identifier. */
              warning (_("Unknown persona '%s' in favorites list."), ids[i]);
              continue;
            }

          /* Mark or unmark the persona as a favourite */
          if (p != null)
            p.is_favourite = add;
        }
    }

  private void _favourite_contacts_changed_cb (string[] added, string[] removed)
    {
      /* Don't listen to favourites updates if the account is disconnected. */
      if (this._conn == null)
        return;

      /* Add favourites */
      if (added.length > 0)
        {
          this._conn.request_handles (-1, HandleType.CONTACT, added,
              (c, ht, h, i, e, w) =>
                {
                  try
                    {
                      this._change_favourites_by_request_handles ((Handle[]) h,
                          i, e, true);
                    }
                  catch (GLib.Error e)
                    {
                      /* Translators: the parameter is an error message. */
                      warning (_("Couldn't add favorite contacts: %s"),
                          e.message);
                    }
                },
              this);
        }

      /* Remove favourites */
      if (removed.length > 0)
        {
          this._conn.request_handles (-1, HandleType.CONTACT, removed,
              (c, ht, h, i, e, w) =>
                {
                  try
                    {
                      this._change_favourites_by_request_handles ((Handle[]) h,
                          i, e, false);
                    }
                  catch (GLib.Error e)
                    {
                      /* Translators: the parameter is an error message. */
                      warning (_("Couldn't remove favorite contacts: %s"),
                          e.message);
                    }
                },
              this);
        }
    }

  /* FIXME: the second generic type for details is "weak GLib.Value", but Vala
   * doesn't accept it as a generic type */
  private void _account_status_changed_cb (uint old_status, uint new_status,
      uint reason, string? dbus_error_name,
      GLib.HashTable<weak string, weak void*>? details)
    {
      debug ("Account '%s' changed status from %u to %u.", this.id, old_status,
          new_status);

      if (new_status == TelepathyGLib.ConnectionStatus.DISCONNECTED)
        {
          /* When disconnecting, we want the PersonaStore to remain alive, but
           * all its Personas to be removed. We do *not* want the PersonaStore
           * to be destroyed, as that makes coming back online hard. */
          this.personas_changed (null, this._personas.get_values (), null, null,
              0);
          this._reset ();
          return;
        }
      else if (new_status != TelepathyGLib.ConnectionStatus.CONNECTED)
        return;

      var conn = this.account.connection;
      conn.notify["connection-ready"].connect (this._connection_ready_cb);

      /* Deal with the case where the connection is already ready
       * FIXME: We have to access the property manually until bgo#571348 is
       * fixed. */
      var connection_ready = false;
      conn.get ("connection-ready", out connection_ready);

      if (connection_ready == true)
        this._connection_ready_cb (conn, null);
      else
        conn.prepare_async.begin (null);
    }

  private void _connection_ready_cb (Object s, ParamSpec? p)
    {
      var c = (Connection) s;
      this._ll.connection_connect_to_new_group_channels (c,
          this._new_group_channels_cb);

      this._ll.connection_get_alias_flags_async.begin (c, (s2, res) =>
          {
            var new_can_alias = MaybeBool.FALSE;
            try
              {
                var flags = this._ll.connection_get_alias_flags_async.end (res);
                if ((flags &
                    ConnectionAliasFlags.CONNECTION_ALIAS_FLAG_USER_SET) > 0)
                  {
                    new_can_alias = MaybeBool.TRUE;
                  }
              }
            catch (GLib.Error e)
              {
                GLib.warning (
                    /* Translators: the first parameter is the display name for
                     * the Telepathy account, and the second is an error
                     * message. */
                    _("Failed to determine whether we can set aliases on Telepathy account '%s': %s"),
                    this.display_name, e.message);
              }

            this._can_alias_personas = new_can_alias;
            this.notify_property ("can-alias-personas");
          });

      this._ll.connection_get_requestable_channel_classes_async.begin (c,
          (s3, res3) =>
          {
            var new_can_group = MaybeBool.FALSE;
            try
              {
                var ll = this._ll;
                GenericArray<weak void*> v;
                int i;

                v = ll.connection_get_requestable_channel_classes_async.end (
                  res3);

                for (i = 0; i < v.length; i++)
                  {
                    unowned ValueArray @class = (ValueArray) v.get (i);
                    var val = @class.get_nth (0);
                    if (val != null)
                      {
                        var props = (HashTable<weak string, weak Value?>)
                            val.get_boxed ();

                        var channel_type = TelepathyGLib.asv_get_string (props,
                            this._tp_channel_channel_type);
                        bool handle_type_valid;
                        var handle_type = TelepathyGLib.asv_get_uint32 (props,
                            this._tp_channel_handle_type,
                            out handle_type_valid);

                        if ((channel_type ==
                              this._tp_channel_contact_list_type) &&
                            handle_type_valid &&
                            (handle_type == HandleType.GROUP))
                          {
                            new_can_group = MaybeBool.TRUE;
                            break;
                          }
                      }
                  }
              }
            catch (GLib.Error e3)
              {
                GLib.warning (
                    /* Translators: the first parameter is the display name for
                     * the Telepathy account, and the second is an error
                     * message. */
                    _("Failed to determine whether we can set groups on Telepathy account '%s': %s"),
                    this.display_name, e3.message);
              }

            this._can_group_personas = new_can_group;
            this.notify_property ("can-group-personas");
          });

      this._add_standard_channel (c, "publish");
      this._add_standard_channel (c, "stored");
      this._add_standard_channel (c, "subscribe");
      this._conn = c;

      /* Add the local user */
      _conn.notify["self-handle"].connect (this._self_handle_changed_cb);
      if (this._conn.self_handle != 0)
        this._self_handle_changed_cb (this._conn, null);

      /* We can only initialise the favourite contacts once _conn is prepared */
      this._initialise_favourite_contacts.begin ();
    }

  private void _self_handle_changed_cb (Object s, ParamSpec? p)
    {
      var c = (Connection) s;

      /* Remove the old self persona */
      if (this._self_contact != null)
        this._ignore_by_handle (this._self_contact.handle, null, null, 0);

      if (c.self_handle == 0)
        return;

      uint[] contact_handles = { c.self_handle };

      /* We have to do it this way instead of using
       * TpLowleve.get_contacts_by_handle_async() as we're in a notification
       * callback */
      c.get_contacts_by_handle (contact_handles,
          (uint[]) this._contact_features,
          (conn, contacts, failed, error, weak_object) =>
            {
              if (error != null)
                {
                  warning (
                      /* Translators: the first parameter is a Telepathy handle,
                       * and the second is an error message. */
                      _("Failed to create contact for self handle '%u': %s"),
                      conn.self_handle, error.message);
                  return;
                }

              debug ("Creating persona from self-handle");

              /* Add the local user */
              Contact contact = contacts[0];
              Persona persona = this._add_persona_from_contact (contact, false);

              GLib.List<Persona> personas = new GLib.List<Persona> ();
              personas.prepend (persona);

              this._self_contact = contact;
              this.personas_changed (personas, null, null, null, 0);
            },
          this);
    }

  private void _new_group_channels_cb (TelepathyGLib.Channel? channel,
      GLib.AsyncResult? result)
    {
      if (channel == null)
        {
          /* Translators: do not translate "NewChannels", as it's a D-Bus
           * signal name. */
          warning (_("Error creating channel for NewChannels signal."));
          return;
        }

      this._set_up_new_group_channel (channel);
      this._channel_group_changes_resolve (channel);
    }

  private void _channel_group_changes_resolve (Channel channel)
    {
      unowned string group = channel.get_identifier ();

      var change_maps = new HashMap<HashSet<Tpf.Persona>, bool> ();
      if (this._group_outgoing_adds[group] != null)
        change_maps.set (this._group_outgoing_adds[group], true);

      if (this._group_outgoing_removes[group] != null)
        change_maps.set (this._group_outgoing_removes[group], false);

      if (change_maps.size < 1)
        return;

      foreach (var entry in change_maps.entries)
        {
          var changes = entry.key;

          foreach (var persona in changes)
            {
              try
                {
                  this._ll.channel_group_change_membership (channel,
                      (Handle) persona.contact.handle, entry.value, null);
                }
              catch (GLib.Error e)
                {
                  if (entry.value == true)
                    {
                      /* Translators: the parameter is a persona identifier and
                       * the second parameter is a group name. */
                      warning (_("Failed to add persona '%s' to group '%s'."),
                          persona.uid, group);
                    }
                  else
                    {
                      warning (
                          /* Translators: the parameter is a persona identifier
                           * and the second parameter is a group name. */
                          _("Failed to remove persona '%s' from group '%s'."),
                          persona.uid, group);
                    }
                }
            }

          changes.clear ();
        }
    }

  private void _set_up_new_standard_channel (Channel channel)
    {
      debug ("Setting up new standard channel '%s'.",
          channel.get_identifier ());

      /* hold a ref to the channel here until it's ready, so it doesn't
       * disappear */
      this._standard_channels_unready[channel.get_identifier ()] = channel;

      channel.notify["channel-ready"].connect ((s, p) =>
        {
          var c = (Channel) s;
          unowned string name = c.get_identifier ();

          debug ("Channel '%s' is ready.", name);

          if (name == "publish")
            {
              this._publish = c;

              c.group_members_changed_detailed.connect (
                  this._publish_channel_group_members_changed_detailed_cb);
            }
          else if (name == "stored")
            {
              this._stored = c;

              c.group_members_changed_detailed.connect (
                  this._stored_channel_group_members_changed_detailed_cb);
            }
          else if (name == "subscribe")
            {
              this._subscribe = c;

              c.group_members_changed_detailed.connect (
                  this._subscribe_channel_group_members_changed_detailed_cb);

              c.group_flags_changed.connect (
                  this._subscribe_channel_group_flags_changed_cb);

              this._subscribe_channel_group_flags_changed_cb (c,
                  c.group_get_flags (), 0);
            }

          this._standard_channels_unready.unset (name);

          c.invalidated.connect (this._channel_invalidated_cb);

          unowned Intset? members = c.group_get_members ();
          if (members != null)
            {
              this._channel_group_pend_incoming_adds.begin (c,
                  members.to_array (), true);
            }
        });
    }

  private void _publish_channel_group_members_changed_detailed_cb (
      Channel channel,
      /* FIXME: Array<uint> => Array<Handle>; parser bug */
      Array<uint> added,
      Array<uint> removed,
      Array<uint> local_pending,
      Array<uint> remote_pending,
      HashTable details)
    {
      if (added.length > 0)
        this._channel_group_pend_incoming_adds.begin (channel, added, true);

      /* we refuse to send these contacts our presence, so remove them */
      for (var i = 0; i < removed.length; i++)
        {
          var handle = removed.index (i);
          this._ignore_by_handle_if_needed (handle, details);
        }

      /* FIXME: continue for the other arrays */
    }

  private void _stored_channel_group_members_changed_detailed_cb (
      Channel channel,
      /* FIXME: Array<uint> => Array<Handle>; parser bug */
      Array<uint> added,
      Array<uint> removed,
      Array<uint> local_pending,
      Array<uint> remote_pending,
      HashTable details)
    {
      if (added.length > 0)
        this._channel_group_pend_incoming_adds.begin (channel, added, true);

      for (var i = 0; i < removed.length; i++)
        {
          var handle = removed.index (i);
          this._ignore_by_handle_if_needed (handle, details);
        }
    }

  private void _subscribe_channel_group_flags_changed_cb (
      Channel? channel,
      uint added,
      uint removed)
    {
      this._update_capability ((ChannelGroupFlags) added,
          (ChannelGroupFlags) removed, ChannelGroupFlags.CAN_ADD,
          ref this._can_add_personas, "can-add-personas");

      this._update_capability ((ChannelGroupFlags) added,
          (ChannelGroupFlags) removed, ChannelGroupFlags.CAN_REMOVE,
          ref this._can_remove_personas, "can-remove-personas");
    }

  private void _update_capability (
      ChannelGroupFlags added,
      ChannelGroupFlags removed,
      ChannelGroupFlags tp_flag,
      ref MaybeBool private_member,
      string prop_name)
    {
      var new_value = private_member;

      if ((added & tp_flag) != 0)
        new_value = MaybeBool.TRUE;

      if ((removed & tp_flag) != 0)
        new_value = MaybeBool.FALSE;

      if (new_value != private_member)
        {
          private_member = new_value;
          this.notify_property (prop_name);
        }
    }

  private void _subscribe_channel_group_members_changed_detailed_cb (
      Channel channel,
      /* FIXME: Array<uint> => Array<Handle>; parser bug */
      Array<uint> added,
      Array<uint> removed,
      Array<uint> local_pending,
      Array<uint> remote_pending,
      HashTable details)
    {
      if (added.length > 0)
        {
          this._channel_group_pend_incoming_adds.begin (channel, added, true);

          /* expose ourselves to anyone we can see */
          if (this._publish != null)
            {
              this._channel_group_pend_incoming_adds.begin (this._publish,
                  added, true);
            }
        }

      /* these contacts refused to send us their presence, so remove them */
      for (var i = 0; i < removed.length; i++)
        {
          var handle = removed.index (i);
          this._ignore_by_handle_if_needed (handle, details);
        }

      /* FIXME: continue for the other arrays */
    }

  private void _channel_invalidated_cb (TelepathyGLib.Proxy proxy, uint domain,
      int code, string message)
    {
      var channel = (Channel) proxy;

      this._channel_group_personas_map.unset (channel);
      this._channel_group_incoming_adds.unset (channel);

      if (proxy == this._publish)
        this._publish = null;
      else if (proxy == this._stored)
        this._stored = null;
      else if (proxy == this._subscribe)
        this._subscribe = null;
      else
        {
          var error = new GLib.Error ((Quark) domain, code, "%s", message);
          var name = channel.get_identifier ();
          this.group_removed (name, error);
          this._groups.unset (name);
        }
    }

  private void _ignore_by_handle_if_needed (uint handle,
      HashTable<string, HashTable<string, Value?>> details)
    {
      unowned TelepathyGLib.Intset members;

      if (this._subscribe != null)
        {
          members = this._subscribe.group_get_members ();
          if (members.is_member (handle))
            return;

          members = this._subscribe.group_get_remote_pending ();
          if (members.is_member (handle))
            return;
        }

      if (this._publish != null)
        {
          members = this._publish.group_get_members ();
          if (members.is_member (handle))
            return;
        }

      unowned string message = TelepathyGLib.asv_get_string (details,
          "message");
      bool valid;
      Persona? actor = null;
      var actor_handle = TelepathyGLib.asv_get_uint32 (details, "actor",
          out valid);
      if (actor_handle > 0 && valid)
        actor = this._handle_persona_map[actor_handle];

      Groupable.ChangeReason reason = Groupable.ChangeReason.NONE;
      var tp_reason = TelepathyGLib.asv_get_uint32 (details, "change-reason",
          out valid);
      if (valid)
        reason = Tpf.PersonaStore._change_reason_from_tp_reason (tp_reason);

      this._ignore_by_handle (handle, message, actor, reason);
    }

  private static Groupable.ChangeReason _change_reason_from_tp_reason (
      uint reason)
    {
      return (Groupable.ChangeReason) reason;
    }

  private void _ignore_by_handle (uint handle, string? message, Persona? actor,
      Groupable.ChangeReason reason)
    {
      var persona = this._handle_persona_map[handle];

      debug ("Ignoring handle %u (persona: %p)", handle, persona);

      if (this._self_contact != null && this._self_contact.handle == handle)
        this._self_contact = null;

      /*
       * remove all handle-keyed entries
       */
      this._handle_persona_map.unset (handle);

      /* skip _channel_group_incoming_adds because they occurred after removal
       */

      if (persona == null)
        return;

      /*
       * remove all persona-keyed entries
       */
      foreach (var channel in this._channel_group_personas_map.keys)
        {
          var members = this._channel_group_personas_map[channel];
          if (members != null)
            members.remove (persona);
        }

      foreach (var name in this._group_outgoing_adds.keys)
        {
          var members = this._group_outgoing_adds[name];
          if (members != null)
            members.remove (persona);
        }

      var personas = new GLib.List<Persona> ();
      personas.append (persona);
      this.personas_changed (null, personas, message, actor, reason);
      this._personas.remove (persona.iid);
    }

  /**
   * Remove a {@link Persona} from the PersonaStore.
   *
   * See {@link Folks.PersonaStore.remove_persona}.
   */
  public override async void remove_persona (Folks.Persona persona)
      throws Folks.PersonaStoreError
    {
      var tp_persona = (Tpf.Persona) persona;

      if (tp_persona.contact == this._self_contact &&
          tp_persona.is_in_contact_list == false)
        {
          throw new PersonaStoreError.UNSUPPORTED_ON_USER (
              _("Personas representing the local user may not be removed."));
        }

      try
        {
          this._ll.channel_group_change_membership (this._stored,
              (Handle) tp_persona.contact.handle, false, null);
        }
      catch (GLib.Error e1)
        {
          warning (
              /* Translators: The first parameter is an identifier, the second
               * is the persona's alias and the third is an error message.
               * "stored" is the name of a program object, and shouldn't be
               * translated. */
              _("Failed to remove persona '%s' (%s) from 'stored' list: %s"),
              tp_persona.uid, tp_persona.alias, e1.message);
        }

      try
        {
          this._ll.channel_group_change_membership (this._subscribe,
              (Handle) tp_persona.contact.handle, false, null);
        }
      catch (GLib.Error e2)
        {
          warning (
              /* Translators: The first parameter is an identifier, the second
               * is the persona's alias and the third is an error message.
               * "subscribe" is the name of a program object, and shouldn't be
               * translated. */
              _("Failed to remove persona '%s' (%s) from 'subscribe' list: %s"),
              tp_persona.uid, tp_persona.alias, e2.message);
        }

      try
        {
          this._ll.channel_group_change_membership (this._publish,
              (Handle) tp_persona.contact.handle, false, null);
        }
      catch (GLib.Error e3)
        {
          warning (
              /* Translators: The first parameter is an identifier, the second
               * is the persona's alias and the third is an error message.
               * "publish" is the name of a program object, and shouldn't be
               * translated. */
              _("Failed to remove persona '%s' (%s) from 'publish' list: %s"),
              tp_persona.uid, tp_persona.alias, e3.message);
        }

      /* the contact will be actually removed (and signaled) when we hear back
       * from the server */
    }

  /* Only non-group contact list channels should use create_personas == true,
   * since the exposed set of Personas are meant to be filtered by them */
  private async void _channel_group_pend_incoming_adds (Channel channel,
      Array<uint> adds,
      bool create_personas)
    {
      var adds_length = adds != null ? adds.length : 0;
      if (adds_length >= 1)
        {
          if (create_personas)
            {
              yield this._create_personas_from_channel_handles_async (channel,
                  adds);
            }

          for (var i = 0; i < adds.length; i++)
            {
              var channel_handle = (Handle) adds.index (i);
              var contact_handle = channel.group_get_handle_owner (
                channel_handle);
              var persona = this._handle_persona_map[contact_handle];
              if (persona == null)
                {
                  HashSet<uint>? contact_handles =
                      this._channel_group_incoming_adds[channel];
                  if (contact_handles == null)
                    {
                      contact_handles = new HashSet<uint> ();
                      this._channel_group_incoming_adds[channel] =
                          contact_handles;
                    }
                  contact_handles.add (contact_handle);
                }
            }
        }

      this._channel_groups_add_new_personas ();
    }

  private void _set_up_new_group_channel (Channel channel)
    {
      /* hold a ref to the channel here until it's ready, so it doesn't
       * disappear */
      this._group_channels_unready[channel.get_identifier ()] = channel;

      channel.notify["channel-ready"].connect ((s, p) =>
        {
          var c = (Channel) s;
          var name = c.get_identifier ();

          this._groups[name] = c;
          this._group_channels_unready.unset (name);

          c.invalidated.connect (this._channel_invalidated_cb);
          c.group_members_changed_detailed.connect (
            this._channel_group_members_changed_detailed_cb);

          unowned Intset members = c.group_get_members ();
          if (members != null)
            {
              this._channel_group_pend_incoming_adds.begin (c,
                members.to_array (), false);
            }
        });
    }

  private void _channel_group_members_changed_detailed_cb (Channel channel,
      /* FIXME: Array<uint> => Array<Handle>; parser bug */
      Array<uint> added,
      Array<uint> removed,
      Array<uint> local_pending,
      Array<uint> remote_pending,
      HashTable details)
    {
      if (added != null)
        this._channel_group_pend_incoming_adds.begin (channel, added, false);

      /* FIXME: continue for the other arrays */
    }

  internal async void _change_group_membership (Folks.Persona persona,
      string group, bool is_member)
    {
      var tp_persona = (Tpf.Persona) persona;
      var channel = this._groups[group];
      var change_map = is_member ? this._group_outgoing_adds :
        this._group_outgoing_removes;
      var change_set = change_map[group];

      if (change_set == null)
        {
          change_set = new HashSet<Tpf.Persona> ();
          change_map[group] = change_set;
        }
      change_set.add (tp_persona);

      if (channel == null)
        {
          /* the changes queued above will be resolve in the NewChannels handler
           */
          this._ll.connection_create_group_async (this.account.connection,
              group);
        }
      else
        {
          /* the channel is already ready, so resolve immediately */
          this._channel_group_changes_resolve (channel);
        }
    }

  private void _change_standard_contact_list_membership (
      TelepathyGLib.Channel channel, Folks.Persona persona, bool is_member,
      string? message)
    {
      var tp_persona = (Tpf.Persona) persona;

      try
        {
          this._ll.channel_group_change_membership (channel,
              (Handle) tp_persona.contact.handle, is_member, message);
        }
      catch (GLib.Error e)
        {
          if (is_member == true)
            {
              warning (
                  /* Translators: the first parameter is a persona identifier,
                   * the second is a contact list identifier and the third is
                   * an error message. */
                  _("Failed to add persona '%s' to contact list '%s': %s"),
                  persona.uid, channel.get_identifier (), e.message);
            }
          else
            {
              warning (
                  /* Translators: the first parameter is a persona identifier,
                   * the second is a contact list identifier and the third is
                   * an error message. */
                  _("Failed to remove persona '%s' from contact list '%s': %s"),
                  persona.uid, channel.get_identifier (), e.message);
            }
        }
    }

  private async Channel? _add_standard_channel (Connection conn, string name)
    {
      Channel? channel = null;

      debug ("Adding standard channel '%s' to connection %p", name, conn);

      /* FIXME: handle the error GLib.Error from this function */
      try
        {
          channel = yield this._ll.connection_open_contact_list_channel_async (
              conn, name);
        }
      catch (GLib.Error e)
        {
          debug ("Failed to add channel '%s': %s\n", name, e.message);

          /* XXX: assuming there's no decent way to recover from this */

          return null;
        }

      this._set_up_new_standard_channel (channel);

      return channel;
    }

  /* FIXME: Array<uint> => Array<Handle>; parser bug */
  private async void _create_personas_from_channel_handles_async (
      Channel channel,
      Array<uint> channel_handles)
    {
      uint[] contact_handles = {};
      for (var i = 0; i < channel_handles.length; i++)
        {
          var channel_handle = (Handle) channel_handles.index (i);
          var contact_handle = channel.group_get_handle_owner (channel_handle);
          Persona? persona = this._handle_persona_map[contact_handle];

          if (persona == null)
            {
              contact_handles += contact_handle;
            }
          else
            {
              /* Mark the persona as having been seen in the contact list.
               * The persona might have originally been discovered by querying
               * the Telepathy connection's self-handle; in this case, its
               * is-in-contact-list property will originally be false, as a
               * contact could be exposed as the self-handle, but not actually
               * be in the user's contact list. */
              debug ("Setting is-in-contact-list for '%s' to true",
                  persona.uid);
              persona.is_in_contact_list = true;
            }
        }

      try
        {
          if (contact_handles.length < 1)
            return;

          GLib.List<TelepathyGLib.Contact> contacts =
              yield this._ll.connection_get_contacts_by_handle_async (
                  this._conn, contact_handles, (uint[]) _contact_features);

          if (contacts == null || contacts.length () < 1)
            return;

          var contacts_array = new TelepathyGLib.Contact[contacts.length ()];
          var j = 0;
          unowned GLib.List<TelepathyGLib.Contact> l = contacts;
          for (; l != null; l = l.next)
            {
              contacts_array[j] = l.data;
              j++;
            }

          this._add_new_personas_from_contacts (contacts_array);
        }
      catch (GLib.Error e)
        {
          warning (
              /* Translators: the first parameter is a channel identifier and
               * the second is an error message.. */
              _("Failed to create personas from incoming contacts in channel '%s': %s"),
              channel.get_identifier (), e.message);
        }
    }

  private async GLib.List<Tpf.Persona>? _create_personas_from_contact_ids (
      string[] contact_ids) throws GLib.Error
    {
      if (contact_ids.length > 0)
        {
          GLib.List<TelepathyGLib.Contact> contacts =
              yield this._ll.connection_get_contacts_by_id_async (
                  this._conn, contact_ids, (uint[]) _contact_features);

          GLib.List<Persona> personas = new GLib.List<Persona> ();
          var err_count = 0;
          var err_string = "";
          unowned GLib.List<TelepathyGLib.Contact> l;
          for (l = contacts; l != null; l = l.next)
            {
              var contact = l.data;

              debug ("Creating persona from contact '%s'", contact.identifier);

              var persona = this._add_persona_from_contact (contact, true);
              if (persona != null)
                personas.prepend (persona);
            }

          if (err_count > 0)
            {
              throw new Folks.PersonaStoreError.CREATE_FAILED (
                  /* Translators: the first parameter is the number of personas
                   * which couldn't be created, and the second is a set of error
                   * message lines, built using the "'%s' (%p): %s" string
                   * above. */
                  ngettext ("Failed to create %u persona:\n%s",
                      "Failed to create %u personas:\n%s", err_count),
                  err_count, err_string);
            }

          if (personas != null)
            this.personas_changed (personas, null, null, null, 0);

          return personas;
        }

      return null;
    }

  private Tpf.Persona? _add_persona_from_contact (Contact contact,
      bool from_contact_list)
    {
      var h = contact.get_handle ();
      Persona? persona = null;

      debug ("Adding persona from contact '%s'", contact.identifier);

      persona = this._handle_persona_map[h];
      if (persona == null)
        {
          persona = new Tpf.Persona (contact, this);

          this._personas.insert (persona.iid, persona);
          this._handle_persona_map[h] = persona;

          /* If the handle is a favourite, ensure the persona's marked
           * as such. This deals with the case where we receive a
           * contact _after_ we've discovered that they're a
           * favourite. */
          persona.is_favourite = this._favourite_handles.contains (h);

          /* Only emit this debug message in the false case to reduce debug
           * spam (see https://bugzilla.gnome.org/show_bug.cgi?id=640901#c2). */
          if (from_contact_list == false)
            {
              debug ("    Setting is-in-contact-list to false");
            }

          persona.is_in_contact_list = from_contact_list;

          return persona;
        }
      else
        {
           debug ("    ...already exists.");

          /* Mark the persona as having been seen in the contact list.
           * The persona might have originally been discovered by querying
           * the Telepathy connection's self-handle; in this case, its
           * is-in-contact-list property will originally be false, as a
           * contact could be exposed as the self-handle, but not actually
           * be in the user's contact list. */
          if (persona.is_in_contact_list == false && from_contact_list == true)
            {
              debug ("    Setting is-in-contact-list to true");
              persona.is_in_contact_list = true;
            }

          return null;
        }
    }

  private void _add_new_personas_from_contacts (Contact[] contacts)
    {
      GLib.List<Persona> personas = new GLib.List<Persona> ();
      foreach (Contact contact in contacts)
        {
          var persona = this._add_persona_from_contact (contact, true);
          if (persona != null)
            personas.prepend (persona);
        }

      this._channel_groups_add_new_personas ();

      if (personas != null)
        this.personas_changed (personas, null, null, null, 0);
    }

  private void _channel_groups_add_new_personas ()
    {
      foreach (var entry in this._channel_group_incoming_adds.entries)
        {
          var channel = (Channel) entry.key;
          var members_added = new GLib.List<Persona> ();

          HashSet<Persona> members = this._channel_group_personas_map[channel];
          if (members == null)
            members = new HashSet<Persona> ();

          debug ("Adding members to channel '%s':", channel.get_identifier ());

          var contact_handles = entry.value;
          if (contact_handles != null && contact_handles.size > 0)
            {
              var contact_handles_added = new HashSet<uint> ();
              foreach (var contact_handle in contact_handles)
                {
                  var persona = this._handle_persona_map[contact_handle];
                  if (persona != null)
                    {
                      debug ("    %s", persona.uid);
                      members.add (persona);
                      members_added.prepend (persona);
                      contact_handles_added.add (contact_handle);
                    }
                }

              foreach (var handle in contact_handles_added)
                contact_handles.remove (handle);
            }

          if (members.size > 0)
            this._channel_group_personas_map[channel] = members;

          var name = channel.get_identifier ();
          if (this._group_is_display_group (name) &&
              members_added.length () > 0)
            {
              members_added.reverse ();
              this.group_members_changed (name, members_added, null);
            }
        }
    }

  private bool _group_is_display_group (string group)
    {
      for (var i = 0; i < this._undisplayed_groups.length; i++)
        {
          if (this._undisplayed_groups[i] == group)
            return false;
        }

      return true;
    }

  /**
   * Add a new {@link Persona} to the PersonaStore.
   *
   * See {@link Folks.PersonaStore.add_persona_from_details}.
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      var contact_id = TelepathyGLib.asv_get_string (details, "contact");
      if (contact_id == null)
        {
          throw new PersonaStoreError.INVALID_ARGUMENT (
              /* Translators: the first two parameters are store identifiers and
               * the third is a contact identifier. */
              _("Persona store (%s, %s) requires the following details:\n    contact (provided: '%s')\n"),
              this.type_id, this.id, contact_id);
        }

      // Optional message to pass to the new persona
      var add_message = TelepathyGLib.asv_get_string (details, "message");
      if (add_message == "")
        add_message = null;

      var status = this.account.get_connection_status (null);
      if ((status == TelepathyGLib.ConnectionStatus.DISCONNECTED) ||
          (status == TelepathyGLib.ConnectionStatus.CONNECTING) ||
          this._conn == null)
        {
          throw new PersonaStoreError.STORE_OFFLINE (
              _("Cannot create a new persona while offline."));
        }

      var contact_ids = new string[1];
      contact_ids[0] = contact_id;

      try
        {
          var personas = yield this._create_personas_from_contact_ids (
              contact_ids);

          if (personas == null)
            {
              /* the persona already existed */
              return null;
            }
          else if (personas.length () == 1)
            {
              var persona = personas.data;

              if (this._subscribe != null)
                this._change_standard_contact_list_membership (this._subscribe,
                    persona, true, add_message);

              if (this._publish != null)
                {
                  var flags = this._publish.group_get_flags ();
                  if ((flags & ChannelGroupFlags.CAN_ADD) ==
                      ChannelGroupFlags.CAN_ADD)
                    {
                      this._change_standard_contact_list_membership (
                          this._publish, persona, true, add_message);
                    }
                }

              return persona;
            }
          else
            {
              /* We ignore the case of an empty list, as it just means the
               * contact was already in our roster */
              var num_personas = personas.length ();
              var message =
                  ngettext (
                      /* Translators: the parameter is the number of personas
                       * which were returned. */
                      "Requested a single persona, but got %u persona back.",
                      "Requested a single persona, but got %u personas back.",
                          num_personas);

              throw new PersonaStoreError.CREATE_FAILED (message, num_personas);
            }
        }
      catch (GLib.Error e)
        {
          /* Translators: the parameter is an error message. */
          throw new PersonaStoreError.CREATE_FAILED (
              _("Failed to add a persona from details: %s"), e.message);
        }
    }

  /**
   * Change the favourite status of a persona in this store.
   *
   * This function is idempotent, but relies upon having a connection to the
   * Telepathy logger service, so may fail if that connection is not present.
   */
  internal async void change_is_favourite (Folks.Persona persona,
      bool is_favourite)
    {
      /* It's possible for us to not be able to connect to the logger;
       * see _connection_ready_cb() */
      if (this._logger == null)
        {
          warning (
              /* Translators: "telepathy-logger" is the name of an application,
               * and should not be translated. */
              _("Failed to change favorite without a connection to the telepathy-logger service."));
          return;
        }

      try
        {
          /* Add or remove the persona to the list of favourites as
           * appropriate. */
          unowned string id = ((Tpf.Persona) persona).contact.get_identifier ();

          if (is_favourite)
            yield this._logger.add_favourite_contact (id);
          else
            yield this._logger.remove_favourite_contact (id);
        }
      catch (DBus.Error e)
        {
          warning (_("Failed to change a persona's favorite status."));
        }
    }

  internal async void change_alias (Tpf.Persona persona, string alias)
    {
      debug ("Changing alias of persona %u to '%s'.", persona.contact.handle,
          alias);
      this._ll.connection_set_contact_alias (this._conn,
          (Handle) persona.contact.handle, alias);
    }
}
