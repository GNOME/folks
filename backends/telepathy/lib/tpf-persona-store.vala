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

extern const string G_LOG_DOMAIN;
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
        ContactFeature.PRESENCE,
        ContactFeature.CONTACT_INFO
      };

  private const string[] _always_writeable_properties =
    {
      "is-favourite"
    };

  private HashMap<string, Persona> _personas;
  private Map<string, Persona> _personas_ro;
  private HashSet<Persona> _persona_set;
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
  private AccountManager _account_manager;
  private Logger _logger;
  private Contact? _self_contact;
  private MaybeBool _can_add_personas = MaybeBool.UNSET;
  private MaybeBool _can_alias_personas = MaybeBool.UNSET;
  private MaybeBool _can_group_personas = MaybeBool.UNSET;
  private MaybeBool _can_remove_personas = MaybeBool.UNSET;
  private bool _is_prepared = false;
  private bool _is_quiescent = false;
  private bool _got_stored_channel_members = false;
  private bool _got_self_handle = false;
  private Debug _debug;
  private PersonaStoreCache _cache;
  private Cancellable? _load_cache_cancellable = null;
  private bool _cached = false;

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
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public override string[] always_writeable_properties
    {
      get { return this._always_writeable_properties; }
    }

  /*
   * Whether this PersonaStore has reached a quiescent state.
   *
   * See {@link Folks.PersonaStore.is_quiescent}.
   *
   * @since 0.6.2
   */
  public override bool is_quiescent
    {
      get { return this._is_quiescent; }
    }

  private void _notify_if_is_quiescent ()
    {
      if (this._got_stored_channel_members == true &&
          this._got_self_handle == true &&
          this._is_quiescent == false)
        {
          this._is_quiescent = true;
          this.notify_property ("is-quiescent");
        }
    }

  /**
   * The {@link Persona}s exposed by this PersonaStore.
   *
   * See {@link Folks.PersonaStore.personas}.
   */
  public override Map<string, Persona> personas
    {
      get { return this._personas_ro; }
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

      this._debug = Debug.dup ();
      this._debug.print_status.connect (this._debug_print_status);

      // Set up the cache
      this._cache = new PersonaStoreCache (this);

      this._reset ();
    }

  ~PersonaStore ()
    {
      this._debug.print_status.disconnect (this._debug_print_status);
      this._debug = null;
      if (this._logger != null)
        this._logger.invalidated.disconnect (this._logger_invalidated_cb);
    }

  private string _format_maybe_bool (MaybeBool input)
    {
      switch (input)
        {
          case MaybeBool.UNSET:
            return "unset";
          case MaybeBool.TRUE:
            return "true";
          case MaybeBool.FALSE:
            return "false";
          default:
            assert_not_reached ();
        }
    }

  private void _debug_print_status (Debug debug)
    {
      const string domain = Debug.STATUS_LOG_DOMAIN;
      const LogLevelFlags level = LogLevelFlags.LEVEL_INFO;

      debug.print_heading (domain, level, "Tpf.PersonaStore (%p)", this);
      debug.print_key_value_pairs (domain, level,
          "ID", this.id,
          "Prepared?", this._is_prepared ? "yes" : "no",
          "Has stored contact members?", this._got_stored_channel_members ? "yes" : "no",
          "Has self handle?", this._got_self_handle ? "yes" : "no",
          "Publish TpChannel", "%p".printf (this._publish),
          "Stored TpChannel", "%p".printf (this._stored),
          "Subscribe TpChannel", "%p".printf (this._subscribe),
          "TpConnection", "%p".printf (this._conn),
          "TpAccountManager", "%p".printf (this._account_manager),
          "Self-TpContact", "%p".printf (this._self_contact),
          "Can add personas?", this._format_maybe_bool (this._can_add_personas),
          "Can alias personas?",
              this._format_maybe_bool (this._can_alias_personas),
          "Can group personas?",
              this._format_maybe_bool (this._can_group_personas),
          "Can remove personas?",
              this._format_maybe_bool (this._can_remove_personas)
      );

      debug.print_line (domain, level, "%u Personas:", this._persona_set.size);
      debug.indent ();

      foreach (var persona in this._persona_set)
        {
          debug.print_heading (domain, level, "Persona (%p)", persona);
          debug.print_key_value_pairs (domain, level,
              "UID", persona.uid,
              "IID", persona.iid,
              "Display ID", persona.display_id,
              "User?", persona.is_user ? "yes" : "no",
              "In contact list?", persona.is_in_contact_list ? "yes" : "no",
              "TpContact", "%p".printf (persona.contact)
          );
        }

      debug.unindent ();

      debug.print_line (domain, level, "%u handle–Persona mappings:",
          this._handle_persona_map.size);
      debug.indent ();

      var iter1 = this._handle_persona_map.map_iterator ();
      while (iter1.next () == true)
        {
          debug.print_line (domain, level,
              "%u → %p", iter1.get_key (), iter1.get_value ());
        }

      debug.unindent ();

      debug.print_line (domain, level, "%u channel group Persona sets:",
          this._channel_group_personas_map.size);
      debug.indent ();

      var iter2 = this._channel_group_personas_map.map_iterator ();
      while (iter2.next () == true)
        {
          debug.print_heading (domain, level,
              "Channel (%p):", iter2.get_key ());

          debug.indent ();

          foreach (var persona in iter2.get_value ())
            {
              debug.print_line (domain, level, "%p", persona);
            }

          debug.unindent ();
        }

      debug.unindent ();

      debug.print_line (domain, level, "%u channel group incoming handle sets:",
          this._channel_group_incoming_adds.size);
      debug.indent ();

      var iter3 = this._channel_group_incoming_adds.map_iterator ();
      while (iter3.next () == true)
        {
          debug.print_heading (domain, level,
              "Channel (%p):", iter3.get_key ());

          debug.indent ();

          foreach (var handle in iter3.get_value ())
            {
              debug.print_line (domain, level, "%u", handle);
            }

          debug.unindent ();
        }

      debug.unindent ();

      debug.print_line (domain, level, "%u group outgoing add sets:",
          this._group_outgoing_adds.size);
      debug.indent ();

      var iter4 = this._group_outgoing_adds.map_iterator ();
      while (iter4.next () == true)
        {
          debug.print_heading (domain, level, "Group (%s):", iter4.get_key ());

          debug.indent ();

          foreach (var persona in iter4.get_value ())
            {
              debug.print_line (domain, level, "%p", persona);
            }

          debug.unindent ();
        }

      debug.unindent ();

      debug.print_line (domain, level, "%u group outgoing remove sets:",
          this._group_outgoing_removes.size);
      debug.indent ();

      var iter5 = this._group_outgoing_removes.map_iterator ();
      while (iter5.next () == true)
        {
          debug.print_heading (domain, level, "Group (%s):", iter5.get_key ());

          debug.indent ();

          foreach (var persona in iter5.get_value ())
            {
              debug.print_line (domain, level, "%p", persona);
            }

          debug.unindent ();
        }

      debug.unindent ();

      debug.print_line (domain, level, "%u unready standard channels:",
          this._standard_channels_unready.size);
      debug.indent ();

      var iter6 = this._standard_channels_unready.map_iterator ();
      while (iter6.next () == true)
        {
          debug.print_line (domain, level,
              "%s → %p", iter6.get_key (), iter6.get_value ());
        }

      debug.unindent ();

      debug.print_line (domain, level, "%u unready group channels:",
          this._group_channels_unready.size);
      debug.indent ();

      var iter7 = this._group_channels_unready.map_iterator ();
      while (iter7.next () == true)
        {
          debug.print_line (domain, level,
              "%s → %p", iter7.get_key (), iter7.get_value ());
        }

      debug.unindent ();

      debug.print_line (domain, level, "%u ready group channels:",
          this._groups.size);
      debug.indent ();

      var iter8 = this._groups.map_iterator ();
      while (iter8.next () == true)
        {
          debug.print_line (domain, level,
              "%s → %p", iter8.get_key (), iter8.get_value ());
        }

      debug.unindent ();

      debug.print_line (domain, level, "%u favourite handles:",
          this._favourite_handles.size);
      debug.indent ();

      foreach (var handle in this._favourite_handles)
        {
          debug.print_line (domain, level, "%u", handle);
        }

      debug.unindent ();

      debug.print_line (domain, level, "");
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

      this._personas = new HashMap<string, Persona> ();
      this._personas_ro = this._personas.read_only_view;
      this._persona_set = new HashSet<Persona> ();

      if (this._conn != null)
        {
          this._conn.notify["self-handle"].disconnect (
              this._self_handle_changed_cb);
          this._conn = null;
        }

      this._handle_persona_map = new HashMap<uint, Persona> ();
      this._channel_group_personas_map =
          new HashMap<Channel, HashSet<Persona>> ();
      this._channel_group_incoming_adds =
          new HashMap<Channel, HashSet<uint>> ();
      this._group_outgoing_adds = new HashMap<string, HashSet<Tpf.Persona>> ();
      this._group_outgoing_removes = new HashMap<string, HashSet<Tpf.Persona>> (
          );

      if (this._publish != null)
        {
          this._disconnect_from_standard_channel (this._publish);
          this._publish = null;
        }

      if (this._stored != null)
        {
          this._disconnect_from_standard_channel (this._stored);
          this._stored = null;
        }

      if (this._subscribe != null)
        {
          this._disconnect_from_standard_channel (this._subscribe);
          this._subscribe = null;
        }

      this._standard_channels_unready = new HashMap<string, Channel> ();
      this._group_channels_unready = new HashMap<string, Channel> ();

      if (this._groups != null)
        {
          foreach (var channel in this._groups.values)
            {
              if (channel != null)
                this._disconnect_from_group_channel (channel);
            }
        }

      this._groups = new HashMap<string, Channel> ();
      this._favourite_handles = new HashSet<uint> ();
      this._self_contact = null;
    }

  /**
   * Prepare the PersonaStore for use.
   *
   * See {@link Folks.PersonaStore.prepare}.
   */
  public override async void prepare () throws GLib.Error
    {
      lock (this._is_prepared)
        {
          if (!this._is_prepared)
            {
              this._account_manager = AccountManager.dup ();

              this._account_manager.account_removed.connect ((a) =>
                {
                  if (this.account == a)
                    {
                      this._emit_personas_changed (null, this._persona_set);
                      this._cache.clear_cache ();
                      this.removed ();
                    }
                });
              this._account_manager.account_validity_changed.connect (
                  (a, valid) =>
                    {
                      if (!valid && this.account == a)
                        {
                          this._emit_personas_changed (null, this._persona_set);
                          this._cache.clear_cache ();
                          this.removed ();
                        }
                    });

              /* We have to connect to the logger before dealing with the
               * account status, because if the account's already connected we
               * want to be able to query favourite information immediately. */
              try
                {
                  this._logger = new Logger (this.id);
                  yield this._logger.prepare ();
                  this._logger.invalidated.connect (
                      this._logger_invalidated_cb);
                  this._logger.favourite_contacts_changed.connect (
                      this._favourite_contacts_changed_cb);
                }
              catch (GLib.Error e)
                {
                  warning (
                      _("Couldn't connect to the telepathy-logger service."));
                  this._logger = null;
                }

              /* Ensure the account's prepared first. */
              yield this.account.prepare_async (null);

              this.account.notify["connection"].connect (
                  this._notify_connection_cb);

              /* immediately handle accounts which are not currently being
               * disconnected */
              if (this.account.connection != null)
                {
                  this._notify_connection_cb (this.account, null);
                }
              else
                {
                  /* If we're disconnected, advertise personas from the cache
                   * instead. */
                  yield this._load_cache ();

                  /* We've reached a quiescent state. */
                  this._got_self_handle = true;
                  this._got_stored_channel_members = true;
                  this._notify_if_is_quiescent ();
                }

              this._is_prepared = true;
              this.notify_property ("is-prepared");
            }
        }
    }

  private void _logger_invalidated_cb ()
    {
      this._logger.invalidated.disconnect (this._logger_invalidated_cb);

      warning (_("Lost connection to the telepathy-logger service."));
      this._logger = null;
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
      catch (GLib.Error e)
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
              warning (_("Unknown Telepathy contact ‘%s’ in favorites list."),
                  ids[i]);
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

  private void _notify_connection_cb (Object s, ParamSpec? p)
    {
      var account = s as TelepathyGLib.Account;

      debug ("Account '%s' connection changed to %p", this.id,
          account.connection);

      /* account disconnected */
      if (account.connection == null)
        {
          /* When disconnecting, we want the PersonaStore to remain alive, but
           * all its Personas to be removed. We do *not* want the PersonaStore
           * to be destroyed, as that makes coming back online hard.
           *
           * We have to start advertising personas from the cache instead.
           * This will implicitly notify about removal of the existing persona
           * set and call this._reset().
           *
           * Before we do this, we store the current set of personas to the
           * cache, assuming we were connected before. */
          if (this._conn != null)
            {
              this._store_cache.begin ((o, r) =>
                {
                  this._store_cache.end (r);

                  this._load_cache.begin ((o2, r2) =>
                    {
                      this._load_cache.end (r2);
                    });
                });
            }

          /* If the account was disabled, remove it. We do this here rather than
           * in a handler for the AccountManager::account-disabled signal so
           * that we can wait until the personas have been stored to the cache,
           * which only happens once the account is disconnected (above). We can
           * do this because it's guaranteed that the account will be
           * disconnected after being disabled (if it was connected to begin
           * with). */
          if (this.account.enabled == false)
            {
              this._emit_personas_changed (null, this._persona_set);
              this.removed ();
            }

          /* If the persona store starts offline, we've reached a quiescent
           * state. */
          this._got_self_handle = true;
          this._got_stored_channel_members = true;
          this._notify_if_is_quiescent ();

          return;
        }

      // We're connected, so can stop advertising personas from the cache
      this._unload_cache ();

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
      FolksTpLowlevel.connection_connect_to_new_group_channels (c,
          this._new_group_channels_cb);

      FolksTpLowlevel.connection_get_alias_flags_async.begin (c, (s2, res) =>
          {
            var new_can_alias = MaybeBool.FALSE;
            try
              {
                var flags =
                    FolksTpLowlevel.connection_get_alias_flags_async.end (res);
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

      FolksTpLowlevel.connection_get_requestable_channel_classes_async.begin (c,
          (s3, res3) =>
          {
            var new_can_group = MaybeBool.FALSE;
            try
              {
                GenericArray<weak void*> v;
                int i;

                v = FolksTpLowlevel.
                    connection_get_requestable_channel_classes_async.end (res3);

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

  /**
   * If our account is disconnected, we want to continue to export a static
   * view of personas from the cache.
   */
  private async void _load_cache ()
    {
      /* Only load from the cache if the account is enabled and valid. */
      if (this.account.enabled == false || this.account.valid == false)
        {
          debug ("Skipping loading cache for Tpf.PersonaStore '%s': " +
              "enabled: %s, valid: %s.", this.id,
              this.account.enabled ? "yes" : "no",
              this.account.valid ? "yes" : "no");

          return;
        }

      debug ("Loading cache for Tpf.PersonaStore '%s'.", this.id);

      var cancellable = new Cancellable ();

      if (this._load_cache_cancellable != null)
        {
          debug ("    Cancelling ongoing loading operation (cancellable: %p).",
              this._load_cache_cancellable);
          this._load_cache_cancellable.cancel ();
        }

      this._load_cache_cancellable = cancellable;

      // Load the persona set from the cache and notify of the change
      var cached_personas = yield this._cache.load_objects (cancellable);
      var old_personas = this._persona_set;

      /* If the load operation was cancelled, don't change the state
       * of the persona store at all. */
      if (cancellable.is_cancelled () == true)
        {
          debug ("    Cancelled (cancellable: %p).", cancellable);
          return;
        }

      this._reset ();
      this._cached = true;

      this._persona_set = new HashSet<Persona> ();
      if (cached_personas != null)
        {
          foreach (var p in cached_personas)
            {
              this._persona_set.add (p);
            }
        }

      this._emit_personas_changed (cached_personas, old_personas,
          null, null, GroupDetails.ChangeReason.NONE);

      this._can_add_personas = MaybeBool.FALSE;
      this._can_alias_personas = MaybeBool.FALSE;
      this._can_group_personas = MaybeBool.FALSE;
      this._can_remove_personas = MaybeBool.FALSE;
    }

  /**
   * When we're about to disconnect, store the current set of personas to the
   * cache file so that we can access them once offline.
   */
  private async void _store_cache ()
    {
      debug ("Storing cache for Tpf.PersonaStore '%s'.", this.id);

      yield this._cache.store_objects (this._persona_set);
    }

  /**
   * When our account is connected again, we can unload the the personas which
   * we're advertising from the cache.
   */
  private void _unload_cache ()
    {
      debug ("Unloading cache for Tpf.PersonaStore '%s'.", this.id);

      // If we're in the process of loading from the cache, cancel that
      if (this._load_cache_cancellable != null)
        {
          debug ("    Cancelling ongoing loading operation (cancellable: %p).",
              this._load_cache_cancellable);
          this._load_cache_cancellable.cancel ();
        }

      this._emit_personas_changed (null, this._persona_set, null, null,
          GroupDetails.ChangeReason.NONE);

      this._reset ();
      this._cached = false;
    }

  private void _self_handle_changed_cb (Object s, ParamSpec? p)
    {
      var c = (Connection) s;

      /* Remove the old self persona */
      if (this._self_contact != null)
        this._ignore_by_handle (this._self_contact.handle, null, null, 0);

      if (c.self_handle == 0)
        {
          /* We can only claim to have reached a quiescent state once we've
           * got the stored contact list and the self handle. */
          this._got_self_handle = true;
          this._notify_if_is_quiescent ();

          return;
        }

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

              var personas = new HashSet<Persona> ();
              if (persona != null)
                personas.add (persona);

              this._self_contact = contact;
              this._emit_personas_changed (personas, null);

              this._got_self_handle = true;
              this._notify_if_is_quiescent ();
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
                  FolksTpLowlevel.channel_group_change_membership (channel,
                      (Handle) persona.contact.handle, entry.value, null);
                }
              catch (GLib.Error e)
                {
                  if (entry.value == true)
                    {
                      /* Translators: the parameter is a persona identifier and
                       * the second parameter is a group name. */
                      warning (_("Failed to add Telepathy contact ‘%s’ to group ‘%s’."),
                          persona.contact.identifier, group);
                    }
                  else
                    {
                      warning (
                          /* Translators: the parameter is a persona identifier
                           * and the second parameter is a group name. */
                          _("Failed to remove Telepathy contact ‘%s’ from group ‘%s’."),
                          persona.contact.identifier, group);
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
          if (members != null && name == "stored")
            {
              this._channel_group_pend_incoming_adds.begin (c,
                  members.to_array (), true, (obj, res) =>
                    {
                      this._channel_group_pend_incoming_adds.end (res);

                      /* We've got some members for the stored channel group. */
                      this._got_stored_channel_members = true;
                      this._notify_if_is_quiescent ();
                    });
            }
          else if (members != null)
            {
              this._channel_group_pend_incoming_adds.begin (c,
                  members.to_array (), true);
            }
        });
    }

  private void _disconnect_from_standard_channel (Channel channel)
    {
      var name = channel.get_identifier ();
      debug ("Disconnecting from channel '%s'.", name);

      channel.invalidated.disconnect (this._channel_invalidated_cb);

      if (name == "publish")
        {
          channel.group_members_changed_detailed.disconnect (
              this._publish_channel_group_members_changed_detailed_cb);
        }
      else if (name == "stored")
        {
          channel.group_members_changed_detailed.disconnect (
              this._stored_channel_group_members_changed_detailed_cb);
        }
      else if (name == "subscribe")
        {
          channel.group_members_changed_detailed.disconnect (
              this._subscribe_channel_group_members_changed_detailed_cb);
          channel.group_flags_changed.disconnect (
              this._subscribe_channel_group_flags_changed_cb);
        }
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
        {
          this._channel_group_pend_incoming_adds.begin (channel, added, true,
              (obj, res) =>
            {
              this._channel_group_pend_incoming_adds.end (res);

              /* We can only claim to have reached a quiescent state once we've
               * got the stored contact list and the self handle. */
              this._got_stored_channel_members = true;
              this._notify_if_is_quiescent ();
            });
        }

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

      GroupDetails.ChangeReason reason = GroupDetails.ChangeReason.NONE;
      var tp_reason = TelepathyGLib.asv_get_uint32 (details, "change-reason",
          out valid);
      if (valid)
        reason = Tpf.PersonaStore._change_reason_from_tp_reason (tp_reason);

      this._ignore_by_handle (handle, message, actor, reason);
    }

  private static GroupDetails.ChangeReason _change_reason_from_tp_reason (
      uint reason)
    {
      return (GroupDetails.ChangeReason) reason;
    }

  private void _ignore_by_handle (uint handle, string? message, Persona? actor,
      GroupDetails.ChangeReason reason)
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

      var personas = new HashSet<Persona> ();
      personas.add (persona);

      this._emit_personas_changed (null, personas, message, actor, reason);
      this._personas.unset (persona.iid);
      this._persona_set.remove (persona);
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
              _("Telepathy contacts representing the local user may not be removed."));
        }

      try
        {
          FolksTpLowlevel.channel_group_change_membership (this._stored,
              (Handle) tp_persona.contact.handle, false, null);
        }
      catch (GLib.Error e1)
        {
          warning (
              /* Translators: The first parameter is a contact identifier, the
               * second is a contact list identifier and the third is an error
               * message. */
              _("Failed to remove Telepathy contact ‘%s’ from ‘%s’ list: %s"),
              tp_persona.contact.identifier, "stored", e1.message);
        }

      try
        {
          FolksTpLowlevel.channel_group_change_membership (this._subscribe,
              (Handle) tp_persona.contact.handle, false, null);
        }
      catch (GLib.Error e2)
        {
          warning (
              /* Translators: The first parameter is a contact identifier, the
               * second is a contact list identifier and the third is an error
               * message. */
              _("Failed to remove Telepathy contact ‘%s’ from ‘%s’ list: %s"),
              tp_persona.contact.identifier, "subscribe", e2.message);
        }

      try
        {
          FolksTpLowlevel.channel_group_change_membership (this._publish,
              (Handle) tp_persona.contact.handle, false, null);
        }
      catch (GLib.Error e3)
        {
          warning (
              /* Translators: The first parameter is a contact identifier, the
               * second is a contact list identifier and the third is an error
               * message. */
              _("Failed to remove Telepathy contact ‘%s’ from ‘%s’ list: %s"),
              tp_persona.contact.identifier, "publish", e3.message);
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

          var existing_channel = this._groups[name];
          if (existing_channel != null)
            {
              /* Somehow, this group channel has already been set up. We have to
               * hold a reference to the existing group while unsetting it in
               * the group map so that unsetting it doesn't cause it to be
               * destroyed. If that were to happen, channel_invalidated_cb()
               * would remove it from the group map a second time, causing a
               * double unref. */
              existing_channel.ref ();
              this._groups.unset (name);
              existing_channel.unref ();
            }

          /* Drop all references before we set the new channel */
          existing_channel = null;

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

  private void _disconnect_from_group_channel (Channel channel)
    {
      var name = channel.get_identifier ();
      debug ("Disconnecting from group channel '%s'.", name);

      channel.group_members_changed_detailed.disconnect (
          this._channel_group_members_changed_detailed_cb);
      channel.invalidated.disconnect (this._channel_invalidated_cb);
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
          FolksTpLowlevel.connection_create_group_async (this.account.connection,
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
          FolksTpLowlevel.channel_group_change_membership (channel,
              (Handle) tp_persona.contact.handle, is_member, message);
        }
      catch (GLib.Error e)
        {
          if (is_member == true)
            {
              warning (
                  /* Translators: The first parameter is a contact identifier,
                   * the second is a contact list identifier and the third is an
                   * error message. */
                  _("Failed to add Telepathy contact ‘%s’ to ‘%s’ list: %s"),
                  tp_persona.contact.identifier, channel.get_identifier (),
                  e.message);
            }
          else
            {
              warning (
                  /* Translators: The first parameter is a contact identifier,
                   * the second is a contact list identifier and the third is an
                   * error message. */
                  _("Failed to remove Telepathy contact ‘%s’ from ‘%s’ list: %s"),
                  tp_persona.contact.identifier, channel.get_identifier (),
                  e.message);
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
          channel =
              yield FolksTpLowlevel.connection_open_contact_list_channel_async (
                  conn, name);
        }
      catch (GLib.Error e)
        {
          debug ("Failed to add channel '%s': %s\n", name, e.message);

          /* If the Connection doesn't support 'stored' channels we
           * pretend we've received the stored channel members.
           *
           * When this happens it probably means the ConnectionManager doesn't
           * implement the Channel.Type.ContactList interface.
           *
           * See: https://bugzilla.gnome.org/show_bug.cgi?id=656184 */
           this._got_stored_channel_members = true;
           this._notify_if_is_quiescent ();

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
              yield FolksTpLowlevel.connection_get_contacts_by_handle_async (
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
              _("Failed to create incoming Telepathy contacts from channel ‘%s’: %s"),
              channel.get_identifier (), e.message);
        }
    }

  private async HashSet<Persona> _create_personas_from_contact_ids (
      string[] contact_ids) throws GLib.Error
    {
      var personas = new HashSet<Persona> ();

      if (contact_ids.length == 0)
        return personas;

      GLib.List<TelepathyGLib.Contact> contacts =
          yield FolksTpLowlevel.connection_get_contacts_by_id_async (
              this._conn, contact_ids, (uint[]) _contact_features);

      unowned GLib.List<TelepathyGLib.Contact> l;
      for (l = contacts; l != null; l = l.next)
        {
          var contact = l.data;

          debug ("Creating persona from contact '%s'", contact.identifier);

          var persona = this._add_persona_from_contact (contact, true);
          if (persona != null)
            personas.add (persona);
        }

      if (personas.size > 0)
        {
          this._emit_personas_changed (personas, null);
        }

      return personas;
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

          this._personas.set (persona.iid, persona);
          this._persona_set.add (persona);
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
      var personas = new HashSet<Persona> ();

      foreach (Contact contact in contacts)
        {
          var persona = this._add_persona_from_contact (contact, true);
          if (persona != null)
            personas.add (persona);
        }

      this._channel_groups_add_new_personas ();

      if (personas.size > 0)
        {
          this._emit_personas_changed (personas, null);
        }
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
              _("Cannot create a new Telepathy contact while offline."));
        }

      var contact_ids = new string[1];
      contact_ids[0] = contact_id;

      try
        {
          var personas = yield this._create_personas_from_contact_ids (
              contact_ids);

          if (personas.size == 0)
            {
              /* the persona already existed */
              return null;
            }
          else if (personas.size == 1)
            {
              /* Get the first (and only) Persona */
              Persona persona = null;
              foreach (var p in personas)
                {
                  persona = p;
                  break;
                }

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
              var num_personas = personas.size;
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
      bool is_favourite) throws PropertyError
    {
      /* It's possible for us to not be able to connect to the logger;
       * see _connection_ready_cb() */
      if (this._logger == null)
        {
          throw new PropertyError.UNKNOWN_ERROR (
              /* Translators: "telepathy-logger" is the name of an application,
               * and should not be translated. */
              _("Failed to change favorite without a connection to the telepathy-logger service."));
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
      catch (GLib.Error e)
        {
          throw new PropertyError.UNKNOWN_ERROR (
              /* Translators: the parameter is a contact identifier. */
              _("Failed to change favorite status for Telepathy contact ‘%s’."),
              ((Tpf.Persona) persona).contact.identifier);
        }
    }

  internal async void change_alias (Tpf.Persona persona, string alias)
    {
      /* Deal with badly-behaved callers */
      if (alias == null)
        {
          alias = "";
        }

      debug ("Changing alias of persona %u to '%s'.", persona.contact.handle,
          alias);
      FolksTpLowlevel.connection_set_contact_alias (this._conn,
          (Handle) persona.contact.handle, alias);
    }
}
