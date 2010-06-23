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
using Gee;
using Tp;
using Tp.ContactFeature;
using Folks;

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
  private HashMap<string, Channel> channels_unready;
  private HashMap<string, Channel> groups;
  private Channel publish;
  private Channel subscribe;
  private Connection conn;
  private TpLowlevel ll;
  private AccountManager account_manager;

  [Property(nick = "basis account",
      blurb = "Telepathy account this store is based upon")]
  public Account account { get; construct; }
  public override string type_id { get; private set; }
  public override string id { get; private set; }
  public override HashTable<string, Persona> personas
    {
      get { return this._personas; }
    }

  public PersonaStore (Account account)
    {
      Object (account: account);

      this.type_id = "telepathy";
      this.id = account.get_object_path (account);

      this._personas = new HashTable<string, Persona> (str_hash,
          str_equal);
      this.conn = null;
      this.handle_persona_map = new HashMap<uint, Persona> ();
      this.channel_group_personas_map = new HashMap<Channel, HashSet<Persona>> (
          direct_hash, direct_equal);
      this.channel_group_incoming_adds = new HashMap<Channel, HashSet<uint>> (
          direct_hash, direct_equal);
      this.group_outgoing_adds = new HashMap<string, HashSet<Tpf.Persona>> ();
      this.group_outgoing_removes = new HashMap<string, HashSet<Tpf.Persona>> (
          );
      this.publish = null;
      this.subscribe = null;
      this.channels_unready = new HashMap<string, Channel> ();
      this.groups = new HashMap<string, Channel> ();
      this.ll = new TpLowlevel ();
      this.account_manager = AccountManager.dup ();

      this.account_manager.account_disabled.connect ((a) =>
        {
          if (this.account == a)
            this.removed ();
        });
      this.account_manager.account_removed.connect ((a) =>
        {
          if (this.account == a)
            this.removed ();
        });
      this.account_manager.account_validity_changed.connect ((a, valid) =>
        {
          if (!valid && this.account == a)
            this.removed ();
        });

      this.account.status_changed.connect (this.account_status_changed_cb);

      Tp.ConnectionStatusReason reason;
      var status = this.account.get_connection_status (out reason);
      /* immediately handle accounts which are not currently being disconnected
       */
      if (status != Tp.ConnectionStatus.DISCONNECTED)
        {
          this.account_status_changed_cb (Tp.ConnectionStatus.DISCONNECTED,
              status, reason, null, null);
        }
    }

  private void account_status_changed_cb (ConnectionStatus old_status,
      ConnectionStatus new_status, ConnectionStatusReason reason,
      string? dbus_error_name, GLib.HashTable? details)
    {
      if (new_status != Tp.ConnectionStatus.CONNECTED)
        return;

      var conn = this.account.get_connection ();
      conn.call_when_ready (this.connection_ready_cb);
    }

  private void connection_ready_cb (Connection conn, GLib.Error? error)
    {
      this.ll.connection_connect_to_new_group_channels (conn,
          this.new_group_channels_cb);

      /* FIXME: uncomment these
      this.add_standard_channel (conn, "stored");
      */
      this.add_standard_channel (conn, "publish");
      this.add_standard_channel (conn, "subscribe");
      this.conn = conn;
    }

  private void new_group_channels_cb (void *data)
    {
      var channel = (Channel) data;
      if (channel == null)
        {
          warning ("error creating channel for NewChannels signal");
          return;
        }

      this.set_up_new_channel (channel, false);
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

  private void set_up_new_channel (Channel channel, bool is_standard)
    {
      /* hold a ref to the channel here until it's ready, so it doesn't
       * disappear */
      this.channels_unready[channel.get_identifier ()] = channel;

      channel.notify["channel-ready"].connect ((s, p) =>
        {
          var c = (Channel) s;
          var name = c.get_identifier ();

          if (is_standard == true)
            {
              if (name == "publish")
                this.publish = c;
              else if (name == "subscribe")
                this.subscribe = c;
            }
          else
            {
              this.groups[name] = c;
            }

          this.channels_unready.remove (name);

          c.invalidated.connect (this.channel_invalidated_cb);
          c.group_members_changed.connect (
            this.channel_group_members_changed_cb);

          unowned IntSet members = c.group_get_members ();
          if (members != null)
            this.channel_group_pend_incoming_adds (c, members.to_array ());
        });
    }

  private void channel_invalidated_cb (Proxy proxy, uint domain, int code,
      string message)
    {
      var channel = (Channel) proxy;

      this.channel_group_personas_map.remove (channel);
      this.channel_group_incoming_adds.remove (channel);

      if (proxy == this.publish)
        this.publish = null;
      else if (proxy == this.subscribe)
        this.subscribe = null;
      else
        {
          var error = new GLib.Error ((Quark) domain, code, message);
          var name = channel.get_identifier ();
          this.group_removed (name, error);
          this.groups.remove (name);
        }
    }

  private void channel_group_pend_incoming_adds (Channel channel,
      Array<uint> adds)
    {
      var adds_length = adds != null ? adds.length : 0;
      if (adds_length >= 1)
        {
          /* this won't complete before we would add the personas to the group,
           * so we have to buffer the contact handles below */
          this.create_personas_from_channel_handles_async (channel, adds);

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

  private void channel_group_members_changed_cb (Channel channel,
      string message,
      /* FIXME: Array<uint> => Array<Handle>; parser bug */
      Array<uint>? added,
      Array<uint>? removed,
      Array<uint>? local_pending,
      Array<uint>? remote_pending,
      uint actor,
      uint reason)
    {
      if (added != null)
        this.channel_group_pend_incoming_adds (channel, added);

      /* FIXME: continue for the other arrays */
    }

  public override async void change_group_membership (Folks.Persona persona,
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

  private void change_standard_contact_list_membership (Tp.Channel channel,
      Folks.Persona persona, bool is_member)
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

      /* FIXME: handle the error GLib.Error from this function */
      try
        {
          channel = yield this.ll.connection_open_contact_list_channel_async (
              conn, name);
        }
      catch (GLib.Error e)
        {
          warning ("failed to add channel '%s': %s\n", name, e.message);

          /* XXX: assuming there's no decent way to recover from this */

          return null;
        }

      this.set_up_new_channel (channel, true);

      return channel;
    }

  /* FIXME: Array<uint> => Array<Handle>; parser bug */
  private void create_personas_from_channel_handles_async (Channel channel,
      Array<uint> channel_handles)
    {
      ContactFeature[] features =
        {
          ALIAS,
          /* XXX: also avatar token? */
          PRESENCE
        };

      Handle[] contact_handles = {};
      for (var i = 0; i < channel_handles.length; i++)
        {
          var channel_handle = (Handle) channel_handles.index (i);
          var contact_handle = channel.group_get_handle_owner (channel_handle);

          if (this.handle_persona_map[contact_handle] == null)
            contact_handles += contact_handle;
        }

      /* FIXME: we have to use 'this' as the weak object because the
        * weak object gets passed into the underlying callback as the
        * object instance; there may be a way to fix this with the
        * instance_pos directive, but I couldn't get it to work */
      if (contact_handles.length > 0)
        this.conn.get_contacts_by_handle (contact_handles, features,
            this.get_contacts_by_handle_cb, this);
    }

  private void get_contacts_by_handle_cb (Connection connection,
      uint n_contacts,
      [CCode (array_length = false)]
      Contact[] contacts,
      uint n_failed,
      [CCode (array_length = false)]
      Handle[] failed,
      GLib.Error error,
      GLib.Object weak_object)
    {
      if (n_failed >= 1)
        warning ("failed to retrieve contacts for handles:");

      for (var i = 0; i < n_failed; i++)
        {
          Handle h = failed[i];
          warning ("    %u", (uint) h);
        }

      /* we have to manually pass the length since we don't get it */
      this.add_new_personas_from_contacts (contacts, n_contacts);
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
          unowned GLib.List<Tp.Contact> contacts =
              yield this.ll.connection_get_contacts_by_id_async (
                  this.conn, contact_ids, features);

          GLib.List<Persona> personas = new GLib.List<Persona> ();
          uint err_count = 0;
          string err_format = "";
          unowned GLib.List<Tp.Contact> l;
          for (l = contacts; l != null; l = l.next)
            {
              var contact = l.data;
              try
                {
                  var persona = new Tpf.Persona (contact, this);
                  personas.prepend (persona);
                }
              catch (Tp.Error e)
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

          return personas;
        }

      return null;
    }

  private void add_new_personas_from_contacts (Contact[] contacts,
      uint n_contacts)
    {
      var personas_new = new HashTable<string, Persona> (str_hash, str_equal);
      for (var i = 0; i < n_contacts; i++)
        {
          var contact = contacts[i];

          try
            {
              var persona = new Tpf.Persona (contact, this);
              if (this._personas.lookup (persona.iid) == null)
                {
                  personas_new.insert (persona.iid, persona);

                  this._personas.insert (persona.iid, persona);
                  this.handle_persona_map[contact.get_handle ()] = persona;
                }
            }
          catch (Tp.Error e)
            {
              warning ("failed to create persona from contact '%s' (%p)",
                  contact.alias, contact);
            }
        }

      this.channel_groups_add_new_personas ();

      if (personas_new.size () >= 1)
        {
          GLib.List<Persona> personas = personas_new.get_values ();
          this.personas_added (personas);
        }
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

          var contact_handles = entry.value;
          if (contact_handles != null && contact_handles.size > 0)
            {
              var contact_handles_added = new HashSet<uint> ();
              foreach (var contact_handle in contact_handles)
                {
                  var persona = this.handle_persona_map[contact_handle];
                  if (persona != null)
                    {
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

  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, string> details) throws Folks.PersonaStoreError
    {
      var contact_id = details.lookup ("contact");
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
          else
            {
              warning ("requested a single persona, but got %u back",
                  personas == null ? 0 : personas.length ());
            }
        }
      catch (GLib.Error e)
        {
          warning ("failed to add a persona from details: %s", e.message);
        }

      return null;
    }
}
