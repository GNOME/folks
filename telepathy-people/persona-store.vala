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
using Tp.Individual;
using Tp.Channel;
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
        private bool conn_prepared = false;
        private Lowlevel ll;

        private void group_members_changed_cb (Channel channel,
                        string message,
                        Array<unowned Handle> added,
                        Array<unowned Handle> removed,
                        Array<unowned Handle> local_pending,
                        Array<unowned Handle> remote_pending,
                        uint actor,
                        uint reason) {
                uint i;

                /* FIXME: cut this */
                stdout.printf ("group members changed: '%s'\n", message);

                for (i = 0; i < added.length; i++) {
                        unowned Handle h = added.index (i);

                        /* FIXME: cut this */
                        stdout.printf ("group-members-changed: got handle: %p\n", h);

                        /* FIXME: probably need to improve the telepathy-vala
                         * binding for Tp.Handle before we can do anything
                         * useful */

                        /* FIXME: create the Tp.Individual, etc. */
                }

                /* FIXME: continue for the other arrays */
        }

        /* FIXME: cut this */
#if 0
        private void foreach_member (uint i, void* userdata) {
                stdout.printf ("got channel member: %u\n", i);

                /* FIXME: use this to look up / create a TpContact (or just
                 * plain TpIndividual) from this handle */

        }
#endif

        private async void add_channel (Connection conn, string name) {
                Channel channel;
                unowned IntSet members;
                unowned Array<unowned Handle> member_array = null;
                uint i;

                /* FIXME: handle the error GLib.Error from this function */
                channel = yield this.ll.connection_open_contact_list_channel_async (
                                conn, name);

                /* FIXME: cut this */
                stdout.printf ("got channel %p (%s, is ready: %u) for store %p\n", channel,
                                channel.get_identifier (), (uint) channel.is_ready (),
                                this);

                /*
                 * FIXME: probably need to call the call_when_ready() function
                 * */
                /* FIXME FIXME FIXME: yup, we need to push this into code that
                 * is called once the channel is ready -- or just use
                 * ensure_ready, or whatever */


                channel.notify["channel-ready"].connect ((s, p) => {
                        stdout.printf ("new value for 'channel-ready': %d\n", 
                                (int) channel.channel_ready);

                });

                channel.group_members_changed.connect (
                                this.group_members_changed_cb);

                members = channel.group_get_members ();
                /* FIXME: use this instead */
#if 0
                /* FIXME: might be worth using a lambda for the function */
                members.foreach (this.foreach_member, null);
#endif

                if (members != null) {
                        member_array = members.to_array ();
                }

                /* FIXME: cut this */
                stdout.printf ("existing members:\n");

                for (i = 0; member_array != null && i < member_array.length; i++) {
                        /* FIXME: factor out this common code with the signal
                         * handler */
                        unowned Handle h = member_array.index (i);

                        /* FIXME: cut this */
                        stdout.printf ("     got handle: %p\n", h);

                        /* FIXME: probably need to improve the telepathy-vala
                         * binding for Tp.Handle before we can do anything
                         * useful */

                        /* FIXME: create the Tp.Individual, etc. */
                }

                /* FIXME: actually, once all the channels are ready */
                /* FIXME: we should probably emit a signal here to indicate the
                 * PersonaStore is ready, since prep() will finish without
                 * waiting for the channels to be opened */
        }

        private void connection_ready_cb (Connection conn, GLib.Error error) {
                if (error != null) {
                        /* FIXME: cut this */
                        stdout.printf ("connection_ready_cb: non-NULL error: %s\n",
                                        error.message);

                } else if (this.conn_prepared == false) {
                        /* FIXME: cut this */
                        stdout.printf ("connection_ready_cb: success\n");

                        /* FIXME: set up a handler for the "NewChannels" signal
                         * */
                        /* FIXME: request 'stored' */
                        /* FIXME: request 'publish' */

                        this.add_channel (conn, "subscribe");

                        this.conn_prepared = true;
                }
        }

        private async void prep_account () {
                bool success;

                /* FIXME: cut this */
                stdout.printf ("about to prep the account\n");

                try {
                        success = yield account.prepare_async (null);
                        if (success == true) {
                                Connection conn = account.get_connection ();

                                /* FIXME: cut this */
                                stdout.printf ("account prep for %s succeeded\n",
                                                this.account.get_display_name ());

                                if (conn == null) {
                                        /* FIXME: cut this */
                                        stdout.printf ("connection offline\n");
                                } else {
                                        /* FIXME: cut this */
                                        stdout.printf ("connection online\n");

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
                /* FIXME: cut this */
                stdout.printf ("creating PersonaStore from account: %p (%s: '%s'), presence: %d\n",
                               account,
                               account.get_protocol (),
                               account.get_display_name (),
                               account.get_current_presence (null, null));


                Object (account: account);

                this.ll = new Lowlevel ();
                this.prep_account ();

                /* FIXME: we need to react to the account going on an offline */
        }
}
