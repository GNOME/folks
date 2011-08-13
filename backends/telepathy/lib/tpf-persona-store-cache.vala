/*
 * Copyright (C) 2011 Collabora Ltd.
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
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;
using Gee;
using Folks;

/**
 * An object cache class which implements caching of sets of
 * {@link Tpf.Persona}s from a given {@link Tpf.PersonaStore}.
 *
 * Each {@link Tpf.Persona} is stored as a serialised {@link Variant} which is
 * a tuple containing the following fields:
 *  # UID (`s`)
 *  # IID (`s`)
 *  # IM address (`s`)
 *  # Protocol (`s`)
 *  # Set of group names (`as`)
 *  # Favourite? (`b`)
 *  # Alias (`s`)
 *  # In contact list? (`b`)
 *  # Avatar file URI (`s`)
 *
 * @since 0.6.0
 */
internal class Tpf.PersonaStoreCache : Folks.ObjectCache<Tpf.Persona>
{
  private weak PersonaStore _store;

  /* Version number of the variant type returned by
   * get_serialised_object_type(). This must be modified whenever that variant
   * type or its semantics are changed, since that would necessitate a cache
   * refresh. */
  private static const uint8 _FILE_FORMAT_VERSION = 1;

  internal PersonaStoreCache (PersonaStore store)
    {
      base ("tpf-persona-stores", store.id);

      this._store = store;
    }

  protected override VariantType get_serialised_object_type ()
    {
      return new VariantType.tuple ({
        VariantType.STRING, // UID
        VariantType.STRING, // IID
        VariantType.STRING, // ID
        VariantType.STRING, // Protocol
        new VariantType.array (VariantType.STRING), // Groups
        VariantType.BOOLEAN, // Favourite?
        VariantType.STRING, // Alias
        VariantType.BOOLEAN, // In contact list?
        VariantType.BOOLEAN, // Is user?
        new VariantType.maybe (VariantType.STRING)  // Avatar
      });
    }

  protected override uint8 get_serialised_object_version ()
    {
      return this._FILE_FORMAT_VERSION;
    }

  protected override Variant serialise_object (Tpf.Persona persona)
    {
      // Sort out the groups
      Variant[] groups = new Variant[persona.groups.size];

      uint i = 0;
      foreach (var group in persona.groups)
        {
          groups[i++] = new Variant.string (group);
        }

      // Sort out the IM addresses (there's guaranteed to only be one)
      string? im_protocol = null;

      foreach (var protocol in persona.im_addresses.get_keys ())
        {
          im_protocol = protocol;
          break;
        }

      // Avatar
      var avatar_file = (persona.avatar != null && persona.avatar is FileIcon) ?
          (persona.avatar as FileIcon).get_file () : null;
      var avatar_variant = (avatar_file != null) ?
          new Variant.string (avatar_file.get_uri ()) : null;

      // Serialise the persona
      return new Variant.tuple ({
        new Variant.string (persona.uid),
        new Variant.string (persona.iid),
        new Variant.string (persona.display_id),
        new Variant.string (im_protocol),
        new Variant.array (VariantType.STRING, groups),
        new Variant.boolean (persona.is_favourite),
        new Variant.string (persona.alias),
        new Variant.boolean (persona.is_in_contact_list),
        new Variant.boolean (persona.is_user),
        new Variant.maybe (VariantType.STRING, avatar_variant)
      });
    }

  protected override Tpf.Persona deserialise_object (Variant variant)
    {
      // Deserialise the persona
      var uid = variant.get_child_value (0).get_string ();
      var iid = variant.get_child_value (1).get_string ();
      var display_id = variant.get_child_value (2).get_string ();
      var im_protocol = variant.get_child_value (3).get_string ();
      var groups = variant.get_child_value (4);
      var is_favourite = variant.get_child_value (5).get_boolean ();
      var alias = variant.get_child_value (6).get_string ();
      var is_in_contact_list = variant.get_child_value (7).get_boolean ();
      var is_user = variant.get_child_value (8).get_boolean ();
      var avatar_variant = variant.get_child_value (9).get_maybe ();

      // Deserialise the groups
      var group_set = new HashSet<string> ();
      for (uint i = 0; i < groups.n_children (); i++)
        {
          group_set.add (groups.get_child_value (i).get_string ());
        }

      // Deserialise the avatar
      var avatar = (avatar_variant != null) ?
          new FileIcon (File.new_for_uri (avatar_variant.get_string ())) :
          null;

      return new Tpf.Persona.from_cache (this._store, uid, iid, display_id,
          im_protocol, group_set, is_favourite, alias, is_in_contact_list,
          is_user, avatar);
    }
}

/* vim: filetype=vala textwidth=80 tabstop=2 expandtab: */
