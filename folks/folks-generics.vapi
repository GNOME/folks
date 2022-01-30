/*
 * generics.vapi - generic Gee interfaces implemented in C
 *
 * Copyright © 2013 Intel Corporation
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 *
 * Authors:
 *      Simon McVittie <simon.mcvittie@collabora.co.uk>
 */

/* Unfortunately, we have to do this as a .vapi because going from C to
 * GIR to Vala loses the generic types. FIXME: GNOME #639908 would
 * make it possible to go via GIR like tests/lib/telepathy/contactlist does. */

[CCode (gir_namespace = "Folks", gir_version = "0.7")]
namespace Folks
{
  [CCode (cheader_filename = "folks/small-set.h")]
  internal class SmallSet<G> : Gee.AbstractSet<G>
  {
    internal static SmallSet<G> empty<G> ();

    internal SmallSet (owned Gee.HashDataFunc<G>? item_hash = null,
        owned Gee.EqualDataFunc<G>? item_equals = null);

    internal static SmallSet<G> copy<G> (Gee.Iterable<G> iterable,
        owned Gee.HashDataFunc<G>? item_hash = null,
        owned Gee.EqualDataFunc<G>? item_equals = null);

#if FOLKS_COMPILATION
    [CCode (cheader_filename = "folks/small-set-internal.h")]
    public unowned G @get (int i);
#endif
  }
}

/* vim:set ft=vala: */
