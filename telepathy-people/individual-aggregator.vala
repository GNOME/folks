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
using Tp.PersonaStore;

public class Tp.IndividualAggregator : Object {
        /* FIXME: cut this?
        private HashTable stores;
        */

        public IndividualAggregator () {
                /* FIXME: see if Gee has something better here
                this.stores = new HashTable ();
                */

                AccountManager manager = AccountManager.dup ();
                /* FIXME: cut the GLib */
                unowned GLib.List<Account> accounts =
                        manager.get_valid_accounts ();

                /* FIXME: cut this
                Account first_account = accounts.first().data;

                stdout.printf ("first account: %p (%s: '%s'), presence: %d\n",
                                first_account,
                                first_account.get_protocol (),
                                first_account.get_display_name (),
                                first_account.get_current_presence (null, null));
                */

                foreach (Account account in accounts) {
                        PersonaStore store;

                        /* FIXME: add this to this's hash */
                        store = new PersonaStore (account);

                }
        }

        public void some_method () {
                /* FIXME: cut this */
                stdout.printf ("IndividualAggregator: telepathy-people says hello!\n");
        }
}
