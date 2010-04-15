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

        private void connection_ready_cb (Connection conn, GLib.Error error) {
                if (error != null) {
                        /* FIXME: cut this */
                        stdout.printf ("connection_ready_cb: non-NULL error: %s\n",
                                        error.message);

                } else {
                        Lowlevel lowlevel;
                        Channel channel;

                        /* FIXME: cut this */
                        stdout.printf ("connection_ready_cb: success\n");

                        /* FIXME: set up a handler for the "NewChannels" signal
                         * */
                        /* FIXME: request 'stored' */
                        /* FIXME: request 'publish' */

                        lowlevel = new Lowlevel ();
                        channel = yield
                                lowlevel.connection_open_contact_list_channel_async (
                                                conn, "subscribe");

                        /* FIXME: cut this */
                        g_debug ("got channel %p", channel);

                        /* FIXME: actually do something with the channel */
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

                this.prep_account ();

                /* FIXME: we need to react to the account going on an offline */
        }
}
