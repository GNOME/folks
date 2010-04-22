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
using Tpp.Individual;
using Tpp.Lowlevel;
using Tpp.Persona;
using Tpp.TpPersona;

/* FIXME: split out the TpAccount-specific parts into a new subclass, since
 * PersonaStore should also be used by non-Telepathy sources */
public class Tpp.PersonaStore : Object
{
  [Property(nick = "basis account",
      blurb = "Telepathy account this store is based upon")]
  public Account account { get; construct; }
  public HashTable<string, Persona> personas { get; private set; }
  public signal void personas_added (GLib.List<Persona> personas);

  private Connection conn;
  private bool conn_prepared = false;
  private Lowlevel ll;
  private HashMap<string, Channel> channels;

  /* FIXME: Array<uint> => Array<Handle>; parser bug */
  private Handle[] glib_handles_array_to_array (Array<uint> hs)
    {
      Handle[] handles = new Handle[hs.length];
      uint i;

      for (i = 0; i < hs.length; i++)
        handles[i] = (Handle) hs.index (i);

      return handles;
    }

  /* FIXME: make this generic and relocate it */
  private GLib.List<Persona> hash_set_to_list (HashSet<Persona> hash_set)
    {
      GLib.List<Persona> list = new GLib.List<Persona> ();

      foreach (var element in hash_set)
        list.prepend (element);

      list.reverse ();

      return list;
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
      uint i;
      HashSet<Persona> persona_set = new HashSet<Persona> ();

      if (n_failed >= 1)
        warning ("failed to retrieve contacts for handles:");

      for (i = 0; i < n_failed; i++)
        {
          Handle h = failed[i];
          warning ("    %u", (uint) h);
        }

      for (i = 0; i < n_contacts; i++)
        {
          Contact contact = contacts[i];
          Persona persona;

          persona = new TpPersona (contact);
          persona_set.add (persona);

          this.personas.insert (persona.iid, persona);
        }

      if (persona_set.size >= 1)
        {
          GLib.List<Persona> personas = this.hash_set_to_list (persona_set);
          this.personas_added (personas);
        }
    }

  /* FIXME: Array<uint> => Array<Handle>; parser bug */
  private void create_personas_from_handles (Array<uint> handles)
    {
      Handle[] handles_array;
      ContactFeature[] features =
        {
          TP_CONTACT_FEATURE_ALIAS,
          /* XXX: also avatar token? */
          TP_CONTACT_FEATURE_PRESENCE
        };
      handles_array = this.glib_handles_array_to_array (handles);

      /* FIXME: we have to use 'this' as the weak object because the
        * weak object gets passed into the underlying callback as the
        * object instance; there may be a way to fix this with the
        * instance_pos directive, but I couldn't get it to work */
      this.conn.get_contacts_by_handle (handles_array, features,
          this.get_contacts_by_handle_cb, this);
    }

  private void group_members_changed_cb (Channel channel,
      string message,
      /* FIXME: Array<uint> => Array<Handle>; parser bug */
      Array<uint> added,
      Array<uint> removed,
      Array<uint> local_pending,
      Array<uint> remote_pending,
      uint actor,
      uint reason)
    {
      /* FIXME: cut this */
      debug ("group members changed: '%s'", message);

      this.create_personas_from_handles (added);

      /* FIXME: continue for the other arrays */
    }

  private async void add_channel (Connection conn, string name)
    {
      Channel channel;

      /* FIXME: handle the error GLib.Error from this function */
      try
        {
          channel = yield this.ll.connection_open_contact_list_channel_async (
              conn, name);
          this.channels[name] = channel;
        }
      catch (GLib.Error e)
        {
          warning ("failed to add channel '%s': %s\n", name, e.message);

          /* XXX: assuming there's no decent way to recover from this */

          return;
        }

      channel.notify["channel-ready"].connect ((s, p) =>
        {
          Channel c = (Channel) s;
          unowned IntSet members_set;

          c.group_members_changed.connect (this.group_members_changed_cb);

          members_set = c.group_get_members ();
          if (members_set != null)
            {
              this.create_personas_from_handles (members_set.to_array ());
            }
        });
    }

  private void connection_ready_cb (Connection conn, GLib.Error error)
    {
      if (error != null)
        warning ("connection_ready_cb: non-NULL error: %s", error.message);
      else if (this.conn_prepared == false)
        {
          /* FIXME: set up a handler for the "NewChannels" signal; do much the
           * same work in the handler as we do in the ensure_channel callback
           * (in tp-lowlevel); remove it once we've received channels for all of
           * {stored, publish, subscribe} */

          /* FIXME: uncomment these
          this.add_channel (conn, "stored");
          this.add_channel (conn, "publish");
          */
          this.add_channel (conn, "subscribe");
          this.conn = conn;
          this.conn_prepared = true;
        }
    }

  private async void prep_account ()
    {
      bool success;

      try
        {
          success = yield account.prepare_async (null);
          if (success == true)
            {
              Connection conn = account.get_connection ();
              if (conn != null)
                conn.call_when_ready (this.connection_ready_cb);
            }
        }
      catch (GLib.Error e)
        {
          warning ("failed to prepare the account '%s': %s",
              this.account.get_display_name (), e.message);
        }
    }

  public PersonaStore (Account account)
    {
      Object (account: account);

      this.personas = new HashTable<string, Persona> (str_hash, str_equal);
      this.conn = null;
      this.channels = new HashMap<string, Channel> ();
      this.ll = new Lowlevel ();
      this.prep_account ();

      /* FIXME: we need to react to the account going on an offline */
    }
}
