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
using Folks;
using Folks.Backends.Kf;

/**
 * A persona subclass which represents a single persona from a simple key file.
 */
public class Folks.Backends.Kf.Persona : Folks.Persona,
    IMable
{
  private unowned GLib.KeyFile key_file;
  /* FIXME: As described in the IMable interface, we have to use
   * GenericArray<string> here rather than just string[], as null-terminated
   * arrays aren't supported as generic types. */
  private HashTable<string, GenericArray<string>> _im_addresses;

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
                  this.key_file.remove_key (this.uid, protocol);
                }
              catch (KeyFileError e)
                {
                  /* Ignore the error, since it's just a group or key not found
                   * error. */
                }
            });

          this._im_addresses = value;

          /* Add the new IM addresses to the key file */
          this._im_addresses.foreach ((k, v) =>
            {
              unowned string protocol = (string) k;
              unowned string[] addresses = (string[]) v;
              this.key_file.set_string_list (this.uid, protocol, addresses);
            });

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
  public Persona (KeyFile key_file, string uid, Folks.PersonaStore store)
    {
      string iid = "key-file:" + uid;
      string[] linkable_properties = { "im-addresses" };

      Object (iid: iid,
              uid: uid,
              store: store,
              linkable_properties: linkable_properties);

      this.key_file = key_file;
      this._im_addresses = new HashTable<string, GenericArray<string>> (
          str_hash, str_equal);

      /* Load the IM addresses from the key file */
      try
        {
          string[] keys = this.key_file.get_keys (uid);
          foreach (string protocol in keys)
            {
              string[] im_addresses = this.key_file.get_string_list (uid,
                  protocol);

              /* FIXME: We have to convert our nice efficient string[] to a
               * GenericArray<string> because Vala doesn't like null-terminated
               * arrays as generic types. */
              GenericArray<string> im_address_array =
                  new GenericArray<string> ();
              foreach (string address in im_addresses)
                im_address_array.add (address);

              this._im_addresses.insert (protocol, im_address_array);
            }
        }
      catch (KeyFileError e)
        {
          /* This should never be reached, as we're listing the keys then
           * iterating through the list. */
          GLib.assert_not_reached ();
        }
    }
}
