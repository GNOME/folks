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
using Tp.Individual;
using Tp.Channel;
using Tp.Contact;
using Tp.ContactFeature;
using Tp.Handle;
using Tp.Account;
using Tp.AccountManager;
using Tp.Lowlevel;

/* FIXME: split out the TpAccount-specific parts into a new subclass, since
 * PersonaStore should also be used by non-Telepathy sources */
public class Tp.PersonaStore : Object {
        [Property(nick = "basis account",
                        blurb = "Telepathy account this store is based upon")]
        public Account account { get; construct; }
        private Connection conn;
        private bool conn_prepared = false;
        private Lowlevel ll;
        private HashMap<string, Channel> channels;

        /* FIXME: Array<uint> => Array<Handle>; parser bug */
        private Handle[] glib_handles_array_to_array (Array<uint> hs) {
                Handle[] handles = new Handle[hs.length];
                uint i;

                for (i = 0; i < hs.length; i++) {
                        handles[i] = (Handle) hs.index (i);
                }

                return handles;
        }

        private void get_contacts_by_handle_cb (Tp.Connection connection,
                        uint n_contacts,
                        [CCode (array_length = false)]
                        Tp.Contact[] contacts,
                        uint n_failed,
                        [CCode (array_length = false)]
                        Tp.Handle[] failed,
                        GLib.Error error,
                        GLib.Object weak_object) {

                uint i;

                /* FIXME: cut this */
                debug ("in get_contacts_by_handle_cb(n_contacts: %u; contacts: %p, n_failed: %u, failed: %p)", n_contacts, contacts,
                                n_failed, failed);

                for (i = 0; i < n_contacts; i++) {
                        Contact contact = contacts[i];

                        debug ("    contact ID: %s (%s)", contact.get_identifier (), contact.get_alias ());
                }

                /* FIXME: cut this */
                debug ("failed contacts:");

                for (i = 0; i < n_failed; i++) {
                        Handle h = failed[i];

                        debug ("    handle: %u", (uint) h);
                }
        }

        /* FIXME: Array<uint> => Array<Handle>; parser bug */
        private void create_individuals (Array<uint> handles) {
                Handle[] handles_array;
                ContactFeature[] features = {
                        TP_CONTACT_FEATURE_ALIAS,
                        /* XXX: also avatar token? */
                        TP_CONTACT_FEATURE_PRESENCE
                };
                uint i;

                /* FIXME: create an individual and add to internal storage */

                /* FIXME: cut this */
                for (i = 0; i < handles.length; i++) {
                        Handle h = (Handle) handles.index (i);

                        debug ("would create individual for handle: %u", (uint) h);
                }

                handles_array = this.glib_handles_array_to_array (handles);

                this.conn.get_contacts_by_handle (handles_array, features,
                                this.get_contacts_by_handle_cb, this.conn);
        }

        private void group_members_changed_cb (Channel channel,
                        string message,
                        /* FIXME: the "unowned" part is just a hack to prevent
                         * the handle from being freed -- we really need to
                         * specify that the Handle is not an object */

                        /* FIXME: Array<uint> => Array<Handle>; parser bug */
                        Array<uint> added,
                        Array<uint> removed,
                        Array<uint> local_pending,
                        Array<uint> remote_pending,
                        uint actor,
                        uint reason) {
                /* FIXME: cut this */
                debug ("group members changed: '%s'", message);

                this.create_individuals (added);

                /* FIXME: continue for the other arrays */
        }

        private async void add_channel (Connection conn, string name) {
                Channel channel;

                debug ("trying to add channel %s", name);

                /* FIXME: handle the error GLib.Error from this function */
                try {
                        channel = yield this.ll.connection_open_contact_list_channel_async (
                                        conn, name);
                        this.channels[name] = channel;
                } catch (GLib.Error e) {
                        stderr.printf ("failed to add channel '%s': %s\n",
                                        name, e.message);

                        /* XXX: assuming there's no decent way to recover from
                         * this */

                        return;
                }

                /* FIXME: cut this */
                debug ("got channel %p (%s, is ready: %u) for store %p", channel,
                                channel.get_identifier (), (uint) channel.is_ready (),
                                this);

                channel.notify["channel-ready"].connect ((s, p) => {
                        Channel c = (Channel) s;
                        unowned IntSet members_set;

                        /* FIXME: cut this */
                        debug ("new value for 'channel-ready': %d",
                                (int) channel.channel_ready);

                        c.group_members_changed.connect (
                                        this.group_members_changed_cb);

                        members_set = c.group_get_members ();

                        if (members_set != null) {
                                this.create_individuals (
                                                members_set.to_array ());
                        }
                });
        }

        private void connection_ready_cb (Connection conn, GLib.Error error) {
                if (error != null) {
                        /* FIXME: cut this */
                        debug ("connection_ready_cb: non-NULL error: %s",
                                        error.message);

                } else if (this.conn_prepared == false) {
                        /* FIXME: cut this */
                        debug ("connection_ready_cb: success");

                        /* FIXME: set up a handler for the "NewChannels" signal;
                         * do much the same work in the handler as we do in the
                         * ensure_channel callback (in tp-lowlevel);
                         * remove it once we've received channels for all of
                         * {stored, publish, subscribe}
                         * */

                        /* FIXME: uncomment these
                        this.add_channel (conn, "stored");
                        this.add_channel (conn, "publish");
                        */
                        this.add_channel (conn, "subscribe");
                        this.conn = conn;
                        this.conn_prepared = true;
                }
        }

        private async void prep_account () {
                bool success;

                /* FIXME: cut this */
                debug ("about to prep the account");

                try {
                        success = yield account.prepare_async (null);
                        if (success == true) {
                                Connection conn = account.get_connection ();

                                /* FIXME: cut this */
                                debug ("account prep for %s succeeded",
                                                this.account.get_display_name ());

                                if (conn == null) {
                                        /* FIXME: cut this */
                                        debug ("connection offline");
                                } else {
                                        /* FIXME: cut this */
                                        debug ("connection online");

                                        conn.call_when_ready (this.connection_ready_cb);
                                }
                        }
                } catch (GLib.Error e) {
                        stderr.printf ("failed to prepare the account '%s': %s",
                                        this.account.get_display_name (),
                                        e.message);
                }
        }

        public PersonaStore (Account account) {
                string status = null;
                string status_message = null;

                /* FIXME: cut this */
                debug ("creating PersonaStore from account: %p (%s: '%s'), presence: (%d: %s; %s)",
                               account,
                               account.get_protocol (),
                               account.get_display_name (),
                               account.get_current_presence (out status,
                                       out status_message),
                               status == null ? status : "(no status)",
                               status_message == null ? status_message : "(no status message)");
                debug ("second try with status: (%s, %s)", status,
                                status_message);


                Object (account: account);

                this.conn = null;
                this.channels = new HashMap<string, Channel> ();
                this.ll = new Lowlevel ();
                this.prep_account ();

                /* FIXME: we need to react to the account going on an offline */
        }
}
