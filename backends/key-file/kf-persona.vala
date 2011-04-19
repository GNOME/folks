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
    AliasDetails,
    ImDetails,
    WebServiceDetails
{
  private unowned GLib.KeyFile _key_file;
  private HashMultiMap<string, string> _im_addresses;
  private HashMultiMap<string, string> _web_service_addresses;
  private string _alias;
  private const string[] _linkable_properties =
    {
      "im-addresses",
      "web-service-addresses"
    };

  /**
   * {@inheritDoc}
   */
  public override string[] linkable_properties
    {
      get { return this._linkable_properties; }
    }

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
          this._key_file.set_string (this.display_id, "__alias", value);

          ((Kf.PersonaStore) this.store).save_key_file.begin ();
        }
    }

  /**
   * {@inheritDoc}
   */
  public MultiMap<string, string> im_addresses
    {
      get
        { return this._im_addresses; }

      set
        {
          /* Remove the current IM addresses from the key file */
          foreach (var protocol in this._im_addresses.get_keys ())
            {
              try
                {
                  this._key_file.remove_key (this.display_id, protocol);
                }
              catch (KeyFileError e)
                {
                  /* Ignore the error, since it's just a group or key not found
                   * error. */
                }
            }

          /* Add the new IM addresses to the key file and build a normalised
           * table of them to set as the new property value */
          var im_addresses = new HashMultiMap<string, string> ();

          foreach (var protocol in value.get_keys ())
            {
              var addresses = value.get (protocol);
              var normalised_addresses = new HashSet<string> ();

              foreach (string address in addresses)
                {
                  string normalised_address;
                  try
                    {
                      normalised_address = ImDetails.normalise_im_address (
                          address, protocol);
                    }
                  catch (ImDetailsError e)
                    {
                      /* Somehow an error has crept into the user's
                       * relationships.ini. Warn of it and ignore the IM
                       * address. */
                      warning (e.message);
                      continue;
                    }

                  normalised_addresses.add (normalised_address);
                  im_addresses.set (protocol, normalised_address);
                }

              string[] addrs = (string[]) normalised_addresses.to_array ();
              addrs.length = normalised_addresses.size;

              this._key_file.set_string_list (this.display_id, protocol, addrs);
            }

          this._im_addresses = im_addresses;

          /* Get the PersonaStore to save the key file */
          ((Kf.PersonaStore) this.store).save_key_file.begin ();
        }
    }

  /**
   * {@inheritDoc}
   */
  public MultiMap<string, string> web_service_addresses
    {
      get
        { return this._web_service_addresses; }

      set
        {
          /* Remove the current web service addresses from the key file */
          foreach (var web_service in this._web_service_addresses.get_keys ())
            {
              try
                {
                  this._key_file.remove_key (this.display_id, "web-service." + web_service);
                }
              catch (KeyFileError e)
                {
                  /* Ignore the error, since it's just a group or key not found
                   * error. */
                }
            }

          /* Add the new web service addresses to the key file and build a
           * table of them to set as the new property value */
          var web_service_addresses = new HashMultiMap<string, string> ();

          foreach (var web_service in value.get_keys ())
            {
              var addresses = value.get (web_service);

              string[] addrs = (string[]) addresses.to_array ();
              addrs.length = addresses.size;

              this._key_file.set_string_list (this.display_id,
                  "web-service." + web_service, addrs);

              foreach (var address in addresses)
                {
                  web_service_addresses.set (web_service, address);
                }
            }

          this._web_service_addresses = web_service_addresses;

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
      var iid = store.id + ":" + id;
      var uid = this.build_uid ("key-file", store.id, id);

      Object (display_id: id,
              iid: iid,
              uid: uid,
              store: store,
              is_user: false);

      debug ("Adding key-file Persona '%s' (IID '%s', group '%s')", uid, iid,
          id);

      this._key_file = key_file;
      this._im_addresses = new HashMultiMap<string, string> ();
      this._web_service_addresses = new HashMultiMap<string, string> ();

      /* Load the IM addresses from the key file */
      try
        {
          var keys = this._key_file.get_keys (this.display_id);
          foreach (unowned string key in keys)
            {
              /* Alias */
              if (key == "__alias")
                {
                  this._alias = this._key_file.get_string (this.display_id,
                      key);
                  debug ("    Loaded alias '%s'.", this._alias);
                  continue;
                }

              /* Web service addresses */
              var decomposed_key = key.split(".", 2);
              if (decomposed_key.length == 2 &&
                  decomposed_key[0] == "web-service")
                {
                  unowned string web_service = decomposed_key[1];
                  var web_service_addresses = this._key_file.get_string_list (
                      this.display_id, web_service);

                  foreach (var web_service_address in web_service_addresses)
                    {
                      this._web_service_addresses.set (web_service,
                          web_service_address);
                    }

                  continue;
                }

              /* IM addresses */
              unowned string protocol = key;
              var im_addresses = this._key_file.get_string_list (
                  this.display_id, protocol);

              foreach (var im_address in im_addresses)
                {
                  string address;
                  try
                    {
                      address = ImDetails.normalise_im_address (im_address,
                          protocol);
                    }
                  catch (ImDetailsError e)
                    {
                      /* Warn of and ignore any invalid IM addresses */
                      warning (e.message);
                      continue;
                    }

                  this._im_addresses.set (protocol, address);
                }
            }
        }
      catch (KeyFileError e)
        {
          /* We get a GROUP_NOT_FOUND exception if we're creating a new
           * Persona, since it doesn't yet exist in the key file. We shouldn't
           * get any other exceptions, since we're iterating through a list of
           * keys we've just retrieved. */
          if (!(e is KeyFileError.GROUP_NOT_FOUND))
            {
              /* Translators: the parameter is an error message. */
              warning (_("Couldn't load data from key file: %s"), e.message);
            }
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
          foreach (var protocol in this._im_addresses.get_keys ())
            {
              var im_addresses = this._im_addresses.get (protocol);

              foreach (string address in im_addresses)
                  callback (protocol + ":" + address);
            }
        }
      else if (prop_name == "web-service-addresses")
        {
          foreach (var web_service in this.web_service_addresses.get_keys ())
            {
              var web_service_addresses =
                  this._web_service_addresses.get (web_service);

              foreach (string address in web_service_addresses)
                  callback (web_service + ":" + address);
            }
        }
      else
        {
          /* Chain up */
          base.linkable_property_to_links (prop_name, callback);
        }
    }
}
