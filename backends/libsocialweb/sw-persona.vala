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
 *       Marco Barisione <marco.barisione@collabora.co.uk>
 */

using GLib;
using Folks;
using SocialWebClient;

/**
 * A persona subclass which represents a single libsocialweb contact.
 */
internal class Folks.Backends.Sw.Persona : Folks.Persona,
    Aliasable,
    AvatarDetails
{
  private const string[] _linkable_properties = {};

  /**
   * The names of the Persona's linkable properties.
   *
   * See {@link Folks.Persona.linkable_properties}.
   */
  public override string[] linkable_properties
    {
      get { return this._linkable_properties; }
    }

  /**
   * An avatar for the Persona.
   *
   * See {@link Folks.HasAvatar.avatar}.
   */
  public File avatar { get; set; }

  /**
   * An alias for the Persona.
   *
   * See {@link Folks.Aliasable.alias}.
   */
  public string alias { get; private set; }

  /**
   * Create a new persona.
   *
   * Create a new persona for the {@link PersonaStore} `store`, representing
   * the libsocialweb contact given by `item`.
   */
  public Persona (PersonaStore store, Item item)
    {
      var id = get_item_id (item);
      var uid = this.build_uid ("folks", store.id, id);
      debug ("Creating new Sw.Persona '%s' for %s UID '%s': %p",
          uid, store.display_name, id, this);
      Object (alias: item.get_value ("name"),
              display_id: id,
              uid: uid,
              iid: store.id + ":" + id,
              store: store,
              is_user: false);
      update (item);
    }

  ~Persona ()
    {
      debug ("Destroying Sw.Persona '%s': %p", this.uid, this);
    }

  public static string? get_item_id (Item item)
    {
      return item.get_value ("id");
    }

  public void update (Item item)
    {
      var name = item.get_value ("name");
      if (name != null && name != alias)
        alias = name;

      var avatar_path = item.get_value ("icon");
      if (avatar_path != null)
        {
          var avatar_file = File.new_for_path (avatar_path);
          if (avatar != avatar_file)
            avatar = avatar_file;
        }
    }
}
