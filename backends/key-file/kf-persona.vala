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
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;
using Gee;
using Folks;
using Folks.Backends.Kf;

/**
 * A persona subclass which represents a single persona from a simple key file.
 *
 * @since 0.1.13
 */
public class Folks.Backends.Kf.Persona : Folks.Persona,
    Aliasable,
    IMable
{
  private unowned GLib.KeyFile key_file;
  /* FIXME: As described in the IMable interface, we have to use
   * GenericArray<string> here rather than just string[], as null-terminated
   * arrays aren't supported as generic types. */
  private HashTable<string, GenericArray<string>> _im_addresses;
  private string _alias;

  /**
   * {@inheritDoc}
   *
   * @since 0.1.15
   */
  public string alias
    {
      get { return this._alias; }

      set
        {
          if (this._alias == value)
            return;

          debug ("Setting alias of Kf.Persona '%s' to '%s'.", this.uid, value);

          this._alias = value;
          this.key_file.set_string (this.display_id, "__alias", value);

          ((Kf.PersonaStore) this.store).save_key_file.begin ();
        }
    }

  /**
   * {@inheritDoc}
   */
  public HashTable<string, GenericArray<string>> im_addresses
    {
      get
        { return this._im_addresses; }

      set
        {
          /* Remove the current IM addresses from the key file */
          this._im_addresses.foreach ((k, v) =>
            {
              try
                {
                  unowned string protocol = (string) k;
                  this.key_file.remove_key (this.display_id, protocol);
                }
              catch (KeyFileError e)
                {
                  /* Ignore the error, since it's just a group or key not found
                   * error. */
                }
            });

          /* Add the new IM addresses to the key file and build a normalised
           * table of them to set as the new property value */
          HashTable<string, GenericArray<string>> im_addresses =
              new HashTable<string, GenericArray<string>> (str_hash, str_equal);

          value.foreach ((k, v) =>
            {
              unowned string protocol = (string) k;
              unowned GenericArray<string> addresses = (GenericArray<string>) v;

              for (int i = 0; i < addresses.length; i++)
                {
                  addresses[i] =
                      IMable.normalise_im_address (addresses[i], protocol);
                }

              unowned string[] _addresses =
                  (string[]) ((PtrArray) addresses).pdata;
              _addresses.length = (int) addresses.length;

              this.key_file.set_string_list (this.display_id, protocol,
                  _addresses);
              im_addresses.insert (protocol, addresses);
            });

          this._im_addresses = im_addresses;

          /* Get the PersonaStore to save the key file */
          ((Kf.PersonaStore) this.store).save_key_file.begin ();
        }
    }

  /**
   * Create a new persona.
   *
   * Create a new persona for the {@link PersonaStore} `store`, representing
   * the Persona given by the group `uid` in the key file `key_file`.
   */
  public Persona (KeyFile key_file, string id, Folks.PersonaStore store)
    {
      string[] linkable_properties = { "im-addresses" };
      string iid = store.id + ":" + id;
      string uid = this.build_uid ("key-file", store.id, id);

      Object (display_id: id,
              iid: iid,
              uid: uid,
              store: store,
              linkable_properties: linkable_properties,
              is_user: false);

      debug ("Adding key-file Persona '%s' (IID '%s', group '%s')", uid, iid,
          id);

      this.key_file = key_file;
      this._im_addresses = new HashTable<string, GenericArray<string>> (
          str_hash, str_equal);

      /* Load the IM addresses from the key file */
      try
        {
          string[] keys = this.key_file.get_keys (this.display_id);
          foreach (string key in keys)
            {
              /* Alias */
              if (key == "__alias")
                {
                  this._alias = this.key_file.get_string (this.display_id, key);
                  debug ("    Loaded alias '%s'.", this._alias);
                  continue;
                }

              /* IM addresses */
              string protocol = key;
              string[] im_addresses = this.key_file.get_string_list (
                  this.display_id, protocol);

              /* FIXME: We have to convert our nice efficient string[] to a
               * GenericArray<string> because Vala doesn't like null-terminated
               * arrays as generic types.
               * We can take this opportunity to remove duplicates. */
              HashSet<string> address_set = new HashSet<string> ();
              GenericArray<string> im_address_array =
                  new GenericArray<string> ();

              foreach (string _address in im_addresses)
                {
                  string address =
                      IMable.normalise_im_address (_address, protocol);

                  if (!address_set.contains (address))
                    {
                      im_address_array.add (address);
                      address_set.add (address);
                    }
                }

              this._im_addresses.insert (protocol, im_address_array);
            }
        }
      catch (KeyFileError e)
        {
          /* We get a GROUP_NOT_FOUND exception if we're creating a new
           * Persona, since it doesn't yet exist in the key file. We shouldn't
           * get any other exceptions, since we're iterating through a list of
           * keys we've just retrieved. */
          if (!(e is KeyFileError.GROUP_NOT_FOUND))
            warning ("Couldn't load data from key file: %s", e.message);
        }
    }

  /**
   * {@inheritDoc}
   */
  public override void linkable_property_to_links (string prop_name,
      Folks.Persona.LinkablePropertyCallback callback)
    {
      if (prop_name == "im-addresses")
        {
          this.im_addresses.foreach ((k, v) =>
            {
              unowned string protocol = (string) k;
              unowned GenericArray<string> im_addresses =
                  (GenericArray<string>) v;

              im_addresses.foreach ((v) =>
                {
                  unowned string address = (string) v;
                  callback (protocol + ":" + address);
                });
            });
        }
      else
        {
          /* Chain up */
          base.linkable_property_to_links (prop_name, callback);
        }
    }
}
