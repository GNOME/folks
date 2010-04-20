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
using Tp.Account;
using Tp.PersonaStore;

public class Tp.IndividualAggregator : Object {
        private HashMap<string, PersonaStore> stores;

        public IndividualAggregator () {
                this.stores = new HashMap<string, PersonaStore> ();

                AccountManager manager = AccountManager.dup ();
                unowned GLib.List<Account> accounts =
                        manager.get_valid_accounts ();

                foreach (Account account in accounts) {
                        PersonaStore store = new PersonaStore (account);

                        this.stores.set (account.get_object_path (account),
                                        store);
                }

                /* FIXME: cut this block */
                debug ("the accounts we've got:");
                foreach (var entry in this.stores) {
                        PersonaStore store = entry.value;
                        debug ("     account name: '%s'",
                                        store.account.get_display_name ());

                        store.personas_added.connect ((s, ps) => {
                                        /* FIXME: cut this */
                                        debug ("got persona store's new personas");

                                        foreach (Persona p in ps) {

                                                /* FIXME: cut this */
                                                debug ("\n" +
                                                       "    uid:   %s\n" +
                                                       "    iid:   %s\n" +
                                                       "    alias: %s",
                                                        p.uid, p.iid, p.alias);

                                                /* FIXME: find correlated
                                                 * personas, then create
                                                 * Individuals out of them, and
                                                 * emit signals for them. */
                                        }
                        });
                }

                /* FIXME: react to accounts being created and deleted */
        }
}
