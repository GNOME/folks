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
using TelepathyGLib.ContactFeature;
using Folks;

/**
 * A persona store which is associated with a single Telepathy account. It will
 * create {@link Persona}s for each of the contacts in the published, stored or
 * subscribed
 * [[http://people.collabora.co.uk/~danni/telepathy-book/chapter.channel.html|channels]]
 * of the account.
 */
public class Tpf.PersonaStore : Folks.PersonaStore
{
  private string[] undisplayed_groups = { "publish", "stored", "subscribe" };

  private HashTable<string, Persona> _personas;
  /* universal, contact owner handles (not channel-specific) */
  private HashMap<uint, Persona> handle_persona_map;
  private HashMap<Channel, HashSet<Persona>> channel_group_personas_map;
  private HashMap<Channel, HashSet<uint>> channel_group_incoming_adds;
  private HashMap<string, HashSet<Tpf.Persona>> group_outgoing_adds;
  private HashMap<string, HashSet<Tpf.Persona>> group_outgoing_removes;
  private HashMap<string, Channel> standard_channels_unready;
  private HashMap<string, Channel> group_channels_unready;
  private HashMap<string, Channel> groups;
  /* FIXME: Should be HashSet<Handle> */
  private HashSet<uint> favourite_handles;
  private Channel publish;
  private Channel stored;
  private Channel subscribe;
  private Connection conn;
  private TpLowlevel ll;
  private AccountManager account_manager;
  private Logger logger;

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
   * {@inheritDoc}
   */
  public override string type_id { get; private set; }

  /**
   * {@inheritDoc}
   */
  public override string display_name { get; private set; }

  /**
   * {@inheritDoc}
   */
  public override string id { get; private set; }

  /**
   * {@inheritDoc}
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
   */
  public PersonaStore (Account account)
    {
      Object (account: account);

      this.type_id = "telepathy";

      this.display_name = account.display_name;
      this.id = account.get_object_path ();

      this.reset ();
    }

  private void reset ()
    {
      /* We do not trust local-xmpp at all, since Persona UIDs can be faked by
       * just changing hostname/username. */
      if (account.get_protocol () == "local-xmpp")
        this.trust_level = PersonaStoreTrust.NONE;
      else
        this.trust_level = PersonaStoreTrust.PARTIAL;

      this._personas = new HashTable<string, Persona> (str_hash,
          str_equal);
      this.conn = null;
      this.handle_persona_map = new HashMap<uint, Persona> ();
      this.channel_group_personas_map = new HashMap<Channel, HashSet<Persona>> (
          );
      this.channel_group_incoming_adds = new HashMap<Channel, HashSet<uint>> ();
      this.group_outgoing_adds = new HashMap<string, HashSet<Tpf.Persona>> ();
      this.group_outgoing_removes = new HashMap<string, HashSet<Tpf.Persona>> (
          );
      this.publish = null;
      this.stored = null;
      this.subscribe = null;
      this.standard_channels_unready = new HashMap<string, Channel> ();
      this.group_channels_unready = new HashMap<string, Channel> ();
      this.groups = new HashMap<string, Channel> ();
      this.favourite_handles = new HashSet<uint> ();
      this.ll = new TpLowlevel ();
    }

  /**
   * {@inheritDoc}
   */
  public override async void prepare ()
    {
      this.account_manager = AccountManager.dup ();

      this.account_manager.account_disabled.connect ((a) =>
        {
          if (this.account == a)
            {
              this.personas_changed (null, this._personas.get_values (), null,
                  null, 0);
              this.removed ();
            }
        });
      this.account_manager.account_removed.connect ((a) =>
        {
          if (this.account == a)
            {
              this.personas_changed (null, this._personas.get_values (), null,
                  null, 0);
              this.removed ();
            }
        });
      this.account_manager.account_validity_changed.connect ((a, valid) =>
        {
          if (!valid && this.account == a)
            {
              this.personas_changed (null, this._personas.get_values (), null,
                  null, 0);
              this.removed ();
            }
        });

      this.account.status_changed.connect (this.account_status_changed_cb);

      TelepathyGLib.ConnectionStatusReason reason;
      var status = this.account.get_connection_status (out reason);
      /* immediately handle accounts which are not currently being disconnected
       */
      if (status != TelepathyGLib.ConnectionStatus.DISCONNECTED)
        {
          this.account_status_changed_cb (
              TelepathyGLib.ConnectionStatus.DISCONNECTED, status, reason, null,
              null);
        }

      try
        {
          this.logger = new Logger (this.id);
          this.logger.invalidated.connect (() =>
            {
              warning ("lost connection to the telepathy-logger service");
              this.logger = null;
            });
          this.logger.favourite_contacts_changed.connect (
              this.favourite_contacts_changed_cb);
        }
      catch (DBus.Error e)
        {
          warning ("couldn't connect to the telepathy-logger service");
          this.logger = null;
        }
    }

  private async void initialise_favourite_contacts ()
    {
      if (this.logger == null)
        return;

      /* Get an initial set of favourite contacts */
      try
        {
          string[] contacts = yield this.logger.get_favourite_contacts ();

          if (contacts.length == 0)
            return;

          /* Note that we don't need to release these handles, as they're
           * also held by the relevant contact objects, and will be released
           * as appropriate by those objects (we're circumventing tp-glib's
           * handle reference counting). */
          this.conn.request_handles (-1, HandleType.CONTACT, contacts,
            (c, ht, h, i, e, w) =>
              {
                try
                  {
                    this.change_favourites_by_request_handles ((Handle[]) h, i,
                        e, true);
                  }
                catch (GLib.Error e)
                  {
                    warning ("couldn't get list of favourite contacts: %s",
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
          warning ("couldn't get list of favourite contacts: %s", e.message);
        }
    }

  private void change_favourites_by_request_handles (Handle[] handles,
      string[] ids, GLib.Error? error, bool add) throws GLib.Error
    {
      if (error != null)
        throw error;

      for (var i = 0; i < handles.length; i++)
        {
          Handle h = handles[i];
          Persona p = this.handle_persona_map[h];

          /* Add/Remove the handle to the set of favourite handles, since we
           * might not have the corresponding contact yet */
          if (add)
            this.favourite_handles.add (h);
          else
            this.favourite_handles.remove (h);

          /* If the persona isn't in the handle_persona_map yet, it's most
           * likely because the account hasn't connected yet (and we haven't
           * received the roster). If there are already entries in
           * handle_persona_map, the account *is* connected and we should
           * warn about the unknown persona. */
          if (p == null && this.handle_persona_map.size > 0)
            {
              warning ("unknown persona '%s' in favourites list", ids[i]);
              continue;
            }

          /* Mark or unmark the persona as a favourite */
          if (p != null)
            p.is_favourite = add;
        }
    }

  private void favourite_contacts_changed_cb (string[] added, string[] removed)
    {
      /* Don't listen to favourites updates if the account is disconnected. */
      if (this.conn == null)
        return;

      /* Add favourites */
      if (added.length > 0)
        {
          this.conn.request_handles (-1, HandleType.CONTACT, added,
              (c, ht, h, i, e, w) =>
                {
                  try
                    {
                      this.change_favourites_by_request_handles ((Handle[]) h,
                          i, e, true);
                    }
                  catch (GLib.Error e)
                    {
                      warning ("couldn't add favourite contacts: %s",
                          e.message);
                    }
                },
              this);
        }

      /* Remove favourites */
      if (removed.length > 0)
        {
          this.conn.request_handles (-1, HandleType.CONTACT, removed,
              (c, ht, h, i, e, w) =>
                {
                  try
                    {
                      this.change_favourites_by_request_handles ((Handle[]) h,
                          i, e, false);
                    }
                  catch (GLib.Error e)
                    {
                      warning ("couldn't remove favourite contacts: %s",
                          e.message);
                    }
                },
              this);
        }
    }

  /* FIXME: the second generic type for details is "weak GLib.Value", but Vala
   * doesn't accept it as a generic type */
  private void account_status_changed_cb (uint old_status, uint new_status,
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
          this.reset ();
          return;
        }
      else if (new_status != TelepathyGLib.ConnectionStatus.CONNECTED)
        return;

      var conn = this.account.get_connection ();
      conn.notify["connection-ready"].connect (this.connection_ready_cb);

      /* Deal with the case where the connection is already ready
       * FIXME: We have to access the property manually until bgo#571348 is
       * fixed. */
      bool connection_ready = false;
      conn.get ("connection-ready", out connection_ready);

      if (connection_ready == true)
        this.connection_ready_cb (conn, null);
      else
        conn.prepare_async.begin (null);
    }

  private void connection_ready_cb (Object s, ParamSpec? p)
    {
      Connection c = (Connection) s;
      this.ll.connection_connect_to_new_group_channels (c,
          (AsyncReadyCallback) this.new_group_channels_cb);

      this.add_standard_channel (c, "publish");
      this.add_standard_channel (c, "stored");
      this.add_standard_channel (c, "subscribe");
      this.conn = c;

      /* We can only initialise the favourite contacts once conn is prepared */
      this.initialise_favourite_contacts.begin ();
    }

  private void new_group_channels_cb (Channel? channel, AsyncResult result)
    {
      if (channel == null)
        {
          warning ("error creating channel for NewChannels signal");
          return;
        }

      this.set_up_new_group_channel (channel);
      this.channel_group_changes_resolve (channel);
    }

  private void channel_group_changes_resolve (Channel channel)
    {
      var group = channel.get_identifier ();

      var change_maps = new HashMap<HashSet<Tpf.Persona>, bool> ();
      if (this.group_outgoing_adds[group] != null)
        change_maps.set (this.group_outgoing_adds[group], true);

      if (this.group_outgoing_removes[group] != null)
        change_maps.set (this.group_outgoing_removes[group], false);

      if (change_maps.size < 1)
        return;

      foreach (var entry in change_maps)
        {
          var changes = entry.key;

          foreach (var persona in changes)
            {
              try
                {
                  this.ll.channel_group_change_membership (channel,
                      (Handle) persona.contact.handle, entry.value);
                }
              catch (GLib.Error e)
                {
                  warning ("failed to change persona %s group %s membership to "
                      + "%s",
                      persona.uid, group, entry.value ? "true" : "false");
                }
            }

          changes.clear ();
        }
    }

  private void set_up_new_standard_channel (Channel channel)
    {
      debug ("Setting up new standard channel '%s'.",
          channel.get_identifier ());

      /* hold a ref to the channel here until it's ready, so it doesn't
       * disappear */
      this.standard_channels_unready[channel.get_identifier ()] = channel;

      channel.notify["channel-ready"].connect ((s, p) =>
        {
          var c = (Channel) s;
          var name = c.get_identifier ();

          debug ("Channel '%s' is ready.", name);

          if (name == "publish")
            {
              this.publish = c;

              c.group_members_changed_detailed.connect (
                  this.publish_channel_group_members_changed_detailed_cb);
            }
          else if (name == "stored")
            {
              this.stored = c;

              c.group_members_changed_detailed.connect (
                  this.stored_channel_group_members_changed_detailed_cb);
            }
          else if (name == "subscribe")
            {
              this.subscribe = c;

              c.group_members_changed_detailed.connect (
                  this.subscribe_channel_group_members_changed_detailed_cb);
            }

          this.standard_channels_unready.unset (name);

          c.invalidated.connect (this.channel_invalidated_cb);

          unowned Intset? members = c.group_get_members ();
          if (members != null)
            {
              this.channel_group_pend_incoming_adds.begin (c,
                  members.to_array (), true);
            }
        });
    }

  private void publish_channel_group_members_changed_detailed_cb (
      Channel channel,
      /* FIXME: Array<uint> => Array<Handle>; parser bug */
      Array<weak uint> added,
      Array<weak uint> removed,
      Array<weak uint> local_pending,
      Array<weak uint> remote_pending,
      HashTable details)
    {
      if (added.length > 0)
        this.channel_group_pend_incoming_adds.begin (channel, added, true);

      /* we refuse to send these contacts our presence, so remove them */
      for (var i = 0; i < removed.length; i++)
        {
          var handle = removed.index (i);
          this.ignore_by_handle_if_needed (handle, details);
        }

      /* FIXME: continue for the other arrays */
    }

  private void stored_channel_group_members_changed_detailed_cb (
      Channel channel,
      /* FIXME: Array<uint> => Array<Handle>; parser bug */
      Array<weak uint> added,
      Array<weak uint> removed,
      Array<weak uint> local_pending,
      Array<weak uint> remote_pending,
      HashTable details)
    {
      if (added.length > 0)
        this.channel_group_pend_incoming_adds.begin (channel, added, true);

      for (var i = 0; i < removed.length; i++)
        {
          var handle = removed.index (i);
          this.ignore_by_handle_if_needed (handle, details);
        }
    }
  private void subscribe_channel_group_members_changed_detailed_cb (
      Channel channel,
      /* FIXME: Array<uint> => Array<Handle>; parser bug */
      Array<weak uint> added,
      Array<weak uint> removed,
      Array<weak uint> local_pending,
      Array<weak uint> remote_pending,
      HashTable details)
    {
      if (added.length > 0)
        {
          this.channel_group_pend_incoming_adds.begin (channel, added, true);

          /* expose ourselves to anyone we can see */
          if (this.publish != null)
            {
              this.channel_group_pend_incoming_adds.begin (this.publish, added,
                  true);
            }
        }

      /* these contacts refused to send us their presence, so remove them */
      for (var i = 0; i < removed.length; i++)
        {
          var handle = removed.index (i);
          this.ignore_by_handle_if_needed (handle, details);
        }

      /* FIXME: continue for the other arrays */
    }

  private void channel_invalidated_cb (Proxy proxy, uint domain, int code,
      string message)
    {
      var channel = (Channel) proxy;

      this.channel_group_personas_map.unset (channel);
      this.channel_group_incoming_adds.unset (channel);

      if (proxy == this.publish)
        this.publish = null;
      else if (proxy == this.stored)
        this.stored = null;
      else if (proxy == this.subscribe)
        this.subscribe = null;
      else
        {
          var error = new GLib.Error ((Quark) domain, code, "%s", message);
          var name = channel.get_identifier ();
          this.group_removed (name, error);
          this.groups.unset (name);
        }
    }

  private void ignore_by_handle_if_needed (uint handle,
      HashTable<string, HashTable<string, Value?>> details)
    {
      unowned TelepathyGLib.Intset members;

      if (this.subscribe != null)
        {
          members = this.subscribe.group_get_members ();
          if (members.is_member (handle))
            return;

          members = this.subscribe.group_get_remote_pending ();
          if (members.is_member (handle))
            return;
        }

      if (this.publish != null)
        {
          members = this.publish.group_get_members ();
          if (members.is_member (handle))
            return;
        }

      string? message = TelepathyGLib.asv_get_string (details, "message");
      bool valid;
      Persona? actor = null;
      uint32 actor_handle = TelepathyGLib.asv_get_uint32 (details, "actor",
          out valid);
      if (actor_handle > 0 && valid)
        actor = this.handle_persona_map[actor_handle];

      Groupable.ChangeReason reason = Groupable.ChangeReason.NONE;
      uint32 tp_reason = TelepathyGLib.asv_get_uint32 (details, "change-reason",
          out valid);
      if (valid)
        reason = change_reason_from_tp_reason (tp_reason);

      this.ignore_by_handle (handle, message, actor, reason);
    }

  private Groupable.ChangeReason change_reason_from_tp_reason (uint reason)
    {
      return (Groupable.ChangeReason) reason;
    }

  private void ignore_by_handle (uint handle, string? message, Persona? actor,
      Groupable.ChangeReason reason)
    {
      var persona = this.handle_persona_map[handle];

      debug ("Ignoring handle %u (persona: %p)", handle, persona);

      /*
       * remove all handle-keyed entries
       */
      this.handle_persona_map.unset (handle);

      /* skip channel_group_incoming_adds because they occurred after removal */

      if (persona == null)
        return;

      /*
       * remove all persona-keyed entries
       */
      foreach (var entry in this.channel_group_personas_map)
        {
          var channel = (Channel) entry.key;
          var members = this.channel_group_personas_map[channel];
          if (members != null)
            members.remove (persona);
        }

      foreach (var entry in this.group_outgoing_adds)
        {
          var name = (string) entry.key;
          var members = this.group_outgoing_adds[name];
          if (members != null)
            members.remove (persona);
        }

      var personas = new GLib.List<Persona> ();
      personas.append (persona);
      this.personas_changed (null, personas, message, actor, reason);
      this._personas.remove (persona.iid);
    }

  /**
   * {@inheritDoc}
   */
  public override async void remove_persona (Folks.Persona persona)
    {
      var tp_persona = (Tpf.Persona) persona;

      try
        {
          this.ll.channel_group_change_membership (this.stored,
              (Handle) tp_persona.contact.handle, false);
        }
      catch (GLib.Error e1)
        {
          warning ("failed to remove persona '%s' (%s) from stored list: %s",
              tp_persona.uid, tp_persona.alias, e1.message);
        }

      try
        {
          this.ll.channel_group_change_membership (this.subscribe,
              (Handle) tp_persona.contact.handle, false);
        }
      catch (GLib.Error e2)
        {
          warning ("failed to remove persona '%s' (%s) from subscribe list: %s",
              tp_persona.uid, tp_persona.alias, e2.message);
        }

      try
        {
          this.ll.channel_group_change_membership (this.publish,
              (Handle) tp_persona.contact.handle, false);
        }
      catch (GLib.Error e3)
        {
          warning ("failed to remove persona '%s' (%s) from publish list: %s",
              tp_persona.uid, tp_persona.alias, e3.message);
        }

      /* the contact will be actually removed (and signaled) when we hear back
       * from the server */
    }

  /* Only non-group contact list channels should use create_personas == true,
   * since the exposed set of Personas are meant to be filtered by them */
  private async void channel_group_pend_incoming_adds (Channel channel,
      Array<uint> adds,
      bool create_personas)
    {
      var adds_length = adds != null ? adds.length : 0;
      if (adds_length >= 1)
        {
          if (create_personas)
            {
              yield this.create_personas_from_channel_handles_async (channel,
                  adds);
            }

          for (var i = 0; i < adds.length; i++)
            {
              var channel_handle = (Handle) adds.index (i);
              var contact_handle = channel.group_get_handle_owner (
                channel_handle);
              var persona = this.handle_persona_map[contact_handle];
              if (persona == null)
                {
                  HashSet<uint>? contact_handles =
                      this.channel_group_incoming_adds[channel];
                  if (contact_handles == null)
                    {
                      contact_handles = new HashSet<uint> ();
                      this.channel_group_incoming_adds[channel] =
                          contact_handles;
                    }
                  contact_handles.add (contact_handle);
                }
            }
        }

      this.channel_groups_add_new_personas ();
    }

  private void set_up_new_group_channel (Channel channel)
    {
      /* hold a ref to the channel here until it's ready, so it doesn't
       * disappear */
      this.group_channels_unready[channel.get_identifier ()] = channel;

      channel.notify["channel-ready"].connect ((s, p) =>
        {
          var c = (Channel) s;
          var name = c.get_identifier ();

          this.groups[name] = c;
          this.group_channels_unready.unset (name);

          c.invalidated.connect (this.channel_invalidated_cb);
          c.group_members_changed_detailed.connect (
            this.channel_group_members_changed_detailed_cb);

          unowned Intset members = c.group_get_members ();
          if (members != null)
            {
              this.channel_group_pend_incoming_adds.begin (c,
                members.to_array (), false);
            }
        });
    }

  private void channel_group_members_changed_detailed_cb (Channel channel,
      /* FIXME: Array<uint> => Array<Handle>; parser bug */
      Array<weak uint> added,
      Array<weak uint> removed,
      Array<weak uint> local_pending,
      Array<weak uint> remote_pending,
      HashTable details)
    {
      if (added != null)
        this.channel_group_pend_incoming_adds.begin (channel, added, false);

      /* FIXME: continue for the other arrays */
    }

  internal async void change_group_membership (Folks.Persona persona,
      string group, bool is_member)
    {
      var tp_persona = (Tpf.Persona) persona;
      var channel = this.groups[group];
      var change_map = is_member ? this.group_outgoing_adds :
        this.group_outgoing_removes;
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
          this.ll.connection_create_group_async (this.account.get_connection (),
              group);
        }
      else
        {
          /* the channel is already ready, so resolve immediately */
          this.channel_group_changes_resolve (channel);
        }
    }

  private void change_standard_contact_list_membership (
      TelepathyGLib.Channel channel, Folks.Persona persona, bool is_member)
    {
      var tp_persona = (Tpf.Persona) persona;

      try
        {
          this.ll.channel_group_change_membership (channel,
              (Handle) tp_persona.contact.handle, is_member);
        }
      catch (GLib.Error e)
        {
          warning ("failed to change persona %s contact list %s " +
              "membership to %s",
              persona.uid, channel.get_identifier (),
              is_member ? "true" : "false");
        }
    }

  private async Channel? add_standard_channel (Connection conn, string name)
    {
      Channel? channel = null;

      debug ("Adding standard channel '%s' to connection %p", name, conn);

      /* FIXME: handle the error GLib.Error from this function */
      try
        {
          channel = yield this.ll.connection_open_contact_list_channel_async (
              conn, name);
        }
      catch (GLib.Error e)
        {
          debug ("Failed to add channel '%s': %s\n", name, e.message);

          /* XXX: assuming there's no decent way to recover from this */

          return null;
        }

      this.set_up_new_standard_channel (channel);

      return channel;
    }

  /* FIXME: Array<uint> => Array<Handle>; parser bug */
  private async void create_personas_from_channel_handles_async (
      Channel channel,
      Array<uint> channel_handles)
    {
      ContactFeature[] features =
        {
          ALIAS,
          /* XXX: also avatar token? */
          PRESENCE
        };

      uint[] contact_handles = {};
      for (var i = 0; i < channel_handles.length; i++)
        {
          var channel_handle = (Handle) channel_handles.index (i);
          var contact_handle = channel.group_get_handle_owner (channel_handle);

          if (this.handle_persona_map[contact_handle] == null)
            contact_handles += contact_handle;
        }

      try
        {
          if (contact_handles.length < 1)
            return;

          GLib.List<TelepathyGLib.Contact> contacts =
              yield this.ll.connection_get_contacts_by_handle_async (
                  this.conn, contact_handles, (uint[]) features);

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

          this.add_new_personas_from_contacts (contacts_array);
        }
      catch (GLib.Error e)
        {
          warning ("failed to create personas from incoming contacts in " +
              "channel '%s': %s",
              channel.get_identifier (), e.message);
        }
    }

  private async GLib.List<Tpf.Persona>? create_personas_from_contact_ids (
      string[] contact_ids) throws GLib.Error
    {
      ContactFeature[] features =
        {
          ALIAS,
          /* XXX: also avatar token? */
          PRESENCE
        };

      if (contact_ids.length > 0)
        {
          GLib.List<TelepathyGLib.Contact> contacts =
              yield this.ll.connection_get_contacts_by_id_async (
                  this.conn, contact_ids, (uint[]) features);

          GLib.List<Persona> personas = new GLib.List<Persona> ();
          uint err_count = 0;
          string err_format = "";
          unowned GLib.List<TelepathyGLib.Contact> l;
          for (l = contacts; l != null; l = l.next)
            {
              var contact = l.data;

              debug ("Creating persona from contact '%s'", contact.identifier);

              try
                {
                  var persona = this.add_persona_from_contact (contact);
                  if (persona != null)
                    personas.prepend (persona);
                }
              catch (Tpf.PersonaError e)
                {
                  if (err_count == 0)
                    err_format = "failed to create %u personas:\n";

                  err_format = "%s        '%s' (%p): %s\n".printf (
                    err_format, contact.alias, contact, e.message);
                  err_count++;
                }
            }

          if (err_count > 0)
            {
              throw new Folks.PersonaStoreError.CREATE_FAILED (err_format,
                  err_count);
            }

          if (personas != null)
            this.personas_changed (personas, null, null, null, 0);

          return personas;
        }

      return null;
    }

  private Tpf.Persona? add_persona_from_contact (Contact contact)
      throws Tpf.PersonaError
    {
      var h = contact.get_handle ();

      debug ("Adding persona from contact '%s'", contact.identifier);

      if (this.handle_persona_map[h] == null)
        {
          var persona = new Tpf.Persona (contact, this);

          this._personas.insert (persona.iid, persona);
          this.handle_persona_map[h] = persona;

          /* If the handle is a favourite, ensure the persona's marked
           * as such. This deals with the case where we receive a
           * contact _after_ we've discovered that they're a
           * favourite. */
          persona.is_favourite = this.favourite_handles.contains (h);

          return persona;
        }

      return null;
    }


  private void add_new_personas_from_contacts (Contact[] contacts)
    {
      GLib.List<Persona> personas = new GLib.List<Persona> ();
      foreach (Contact contact in contacts)
        {
          try
            {
              var persona = this.add_persona_from_contact (contact);
              if (persona != null)
                personas.prepend (persona);
            }
          catch (Tpf.PersonaError e)
            {
              warning ("failed to create persona from contact '%s' (%p)",
                  contact.alias, contact);
            }
        }

      this.channel_groups_add_new_personas ();

      if (personas != null)
        this.personas_changed (personas, null, null, null, 0);
    }

  private void channel_groups_add_new_personas ()
    {
      foreach (var entry in this.channel_group_incoming_adds)
        {
          var channel = (Channel) entry.key;
          var members_added = new GLib.List<Persona> ();

          HashSet<Persona> members = this.channel_group_personas_map[channel];
          if (members == null)
            members = new HashSet<Persona> ();

          debug ("Adding members to channel '%s':", channel.get_identifier ());

          var contact_handles = entry.value;
          if (contact_handles != null && contact_handles.size > 0)
            {
              var contact_handles_added = new HashSet<uint> ();
              foreach (var contact_handle in contact_handles)
                {
                  var persona = this.handle_persona_map[contact_handle];
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
            this.channel_group_personas_map[channel] = members;

          var name = channel.get_identifier ();
          if (this.group_is_display_group (name) &&
              members_added.length () > 0)
            {
              members_added.reverse ();
              this.group_members_changed (name, members_added, null);
            }
        }
    }

  private bool group_is_display_group (string group)
    {
      for (var i = 0; i < this.undisplayed_groups.length; i++)
        {
          if (this.undisplayed_groups[i] == group)
            return false;
        }

      return true;
    }

  /**
   * {@inheritDoc}
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      var contact_id = TelepathyGLib.asv_get_string (details, "contact");
      if (contact_id == null)
        {
          throw new PersonaStoreError.INVALID_ARGUMENT (
              "persona store (%s, %s) requires the following details:\n" +
              "    contact (provided: '%s')\n",
              this.type_id, this.id, contact_id);
        }

      string[] contact_ids = new string[1];
      contact_ids[0] = contact_id;

      try
        {
          var personas = yield create_personas_from_contact_ids (
              contact_ids);

          if (personas != null && personas.length () == 1)
            {
              var persona = personas.data;

              if (this.subscribe != null)
                change_standard_contact_list_membership (subscribe, persona,
                    true);

              if (this.publish != null)
                {
                  var flags = publish.group_get_flags ();
                  if ((flags & ChannelGroupFlags.CAN_ADD) ==
                      ChannelGroupFlags.CAN_ADD)
                    {
                      change_standard_contact_list_membership (publish, persona,
                          true);
                    }
                }

              return persona;
            }
          else if (personas != null && personas.length () > 1)
            {
              /* We ignore the case of an empty list, as it just means the
               * contact was already in our roster */
              warning ("requested a single persona, but got %u back",
                  personas.length ());
            }
        }
      catch (GLib.Error e)
        {
          warning ("failed to add a persona from details: %s", e.message);
        }

      return null;
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
       * see connection_ready_cb() */
      if (this.logger == null)
        {
          warning ("failed to change favourite without connection to the " +
                   "telepathy-logger service");
          return;
        }

      try
        {
          /* Add or remove the persona to the list of favourites as
           * appropriate. */
          var id = ((Tpf.Persona) persona).contact.get_identifier ();

          if (is_favourite)
            yield this.logger.add_favourite_contact (id);
          else
            yield this.logger.remove_favourite_contact (id);
        }
      catch (DBus.Error e)
        {
          warning ("failed to change a persona's favourite status");
        }
    }

  internal async void change_alias (Tpf.Persona persona, string alias)
    {
      debug ("Changing alias of persona %u to '%s'.", persona.contact.handle,
          alias);
      this.ll.connection_set_contact_alias (this.conn,
          (Handle) persona.contact.handle, alias);
    }
}
