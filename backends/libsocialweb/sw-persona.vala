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
    AvatarDetails,
    NameDetails
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
   * {@inheritDoc}
   */
  public StructuredName structured_name { get; private set; }

  /**
   * {@inheritDoc}
   */
  public string full_name { get; private set; }

  private string _nickname;
  /**
   * {@inheritDoc}
   */
  public string nickname { get { return this._nickname; } }

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
      Object (display_id: id,
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
      var nickname = item.get_value ("name");
      if (nickname != null && this._nickname != nickname)
        {
          this._nickname = nickname;
          this.notify_property ("nickname");
        }

      var avatar_path = item.get_value ("icon");
      if (avatar_path != null)
        {
          var avatar_file = File.new_for_path (avatar_path);
          if (this.avatar != avatar_file)
            this.avatar = avatar_file;
        }

      var structured_name = new StructuredName.simple (
          item.get_value ("n.family"), item.get_value ("n.given"));
      if (!structured_name.is_empty ())
        this.structured_name = structured_name;
      else if (this.structured_name != null)
        this.structured_name = null;

      var full_name = item.get_value ("fn");
      if (this.full_name != full_name)
        this.full_name = full_name;
    }
}
