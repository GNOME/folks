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
using Tp.Alias;
using Tp.Contact;
using Tp.Persona;

public class Tp.TpPersona : Persona, Alias {
        public Contact contact { get; construct; }
        public override string alias { get; set; }

        public TpPersona (Contact contact) {
                string alias;
                string uid;

                uid = contact.get_identifier ();
                if (uid == null || uid == "") {
                        /* FIXME: throw an exception */
                }

                alias = contact.get_alias ();
                if (alias == null || alias == "") {
                        alias = uid;
                }

                Object (alias: alias,
                        contact: contact,
                        /* FIXME: we'll probably need to include the ID for the
                         * contact's account in the iid */
                        iid: uid,
                        uid: uid);
        }
}
