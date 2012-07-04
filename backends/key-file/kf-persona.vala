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
  private HashMultiMap<string, ImFieldDetails> _im_addresses;
  private HashMultiMap<string, WebServiceFieldDetails> _web_service_addresses;
  private string _alias = ""; /* must not be null */
  private const string[] _linkable_properties =
    {
      "im-addresses",
      "web-service-addresses"
    };
  private const string[] _writeable_properties =
    {
      "alias",
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
   * @since 0.6.0
   */
  public override string[] writeable_properties
    {
      get { return this._writeable_properties; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.1.15
   */
  [CCode (notify = false)]
  public string alias
    {
      get { return this._alias; }
      set { this.change_alias.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_alias (string alias) throws PropertyError
    {
      /* Deal with badly-behaved callers. */
      if (alias == null)
        {
          alias = "";
        }

      if (this._alias == alias)
        {
          return;
        }

      debug ("Setting alias of Kf.Persona '%s' to '%s'.", this.uid, alias);

      unowned KeyFile key_file = ((Kf.PersonaStore) this.store).get_key_file ();
      key_file.set_string (this.display_id, "__alias", alias);
      yield ((Kf.PersonaStore) this.store).save_key_file ();

      this._alias = alias;
      this.notify_property ("alias");
    }

  /**
   * {@inheritDoc}
   */
  [CCode (notify = false)]
  public MultiMap<string, ImFieldDetails> im_addresses
    {
      get { return this._im_addresses; }
      set { this.change_im_addresses.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_im_addresses (
      MultiMap<string, ImFieldDetails> im_addresses) throws PropertyError
    {
      unowned KeyFile key_file = ((Kf.PersonaStore) this.store).get_key_file ();

      /* Remove the current IM addresses from the key file */
      foreach (var protocol1 in this._im_addresses.get_keys ())
        {
          try
            {
              key_file.remove_key (this.display_id, protocol1);
            }
          catch (KeyFileError e1)
            {
              /* Ignore the error, since it's just a group or key not found
               * error. */
            }
        }

      /* Add the new IM addresses to the key file and build a normalised
       * table of them to set as the new property value */
      var new_im_addresses = new HashMultiMap<string, ImFieldDetails> (
          null, null,
           AbstractFieldDetails<string>.hash_static,
           AbstractFieldDetails<string>.equal_static);

      foreach (var protocol2 in im_addresses.get_keys ())
        {
          var addresses = im_addresses.get (protocol2);
          var normalised_addresses = new HashSet<string> ();

          foreach (var im_fd in addresses)
            {
              string normalised_address;
              try
                {
                  normalised_address = ImDetails.normalise_im_address (
                      im_fd.value, protocol2);
                }
               catch (ImDetailsError e2)
                {
                  throw new PropertyError.INVALID_VALUE (
                      /* Translators: this is an error message for if the user
                       * provides an invalid IM address. The first parameter is
                       * an IM address (e.g. “foo@jabber.org”), the second is
                       * the name of a protocol (e.g. “jabber”) and the third is
                       * an error message. */
                      _("Invalid IM address ‘%s’ for protocol ‘%s’: %s"),
                      im_fd.value, protocol2, e2.message);
                }

              normalised_addresses.add (normalised_address);
              var new_im_fd = new ImFieldDetails (normalised_address);
              new_im_addresses.set (protocol2, new_im_fd);
            }

          string[] addrs = (string[]) normalised_addresses.to_array ();
          addrs.length = normalised_addresses.size;

          key_file.set_string_list (this.display_id, protocol2, addrs);
        }

      /* Get the PersonaStore to save the key file */
      yield ((Kf.PersonaStore) this.store).save_key_file ();

      this._im_addresses = new_im_addresses;
      this.notify_property ("im-addresses");
    }

  /**
   * {@inheritDoc}
   */
  [CCode (notify = false)]
  public MultiMap<string, WebServiceFieldDetails> web_service_addresses
    {
      get { return this._web_service_addresses; }
      set { this.change_web_service_addresses.begin (value); }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public async void change_web_service_addresses (
      MultiMap<string, WebServiceFieldDetails> web_service_addresses)
          throws PropertyError
    {
      unowned KeyFile key_file = ((Kf.PersonaStore) this.store).get_key_file ();

      /* Remove the current web service addresses from the key file */
      foreach (var web_service1 in this._web_service_addresses.get_keys ())
        {
          try
            {
              key_file.remove_key (this.display_id,
                  "web-service." + web_service1);
            }
          catch (KeyFileError e)
            {
              /* Ignore the error, since it's just a group or key not found
               * error. */
            }
        }

      /* Add the new web service addresses to the key file and build a
       * table of them to set as the new property value */
      var new_web_service_addresses =
        new HashMultiMap<string, WebServiceFieldDetails> (
            null, null,
             AbstractFieldDetails<string>.hash_static,
             AbstractFieldDetails<string>.equal_static);

      foreach (var web_service2 in web_service_addresses.get_keys ())
        {
          var ws_fds = web_service_addresses.get (web_service2);

          string[] addrs = new string[0];
          foreach (var ws_fd1 in ws_fds)
            addrs += ws_fd1.value;

          key_file.set_string_list (this.display_id,
              "web-service." + web_service2, addrs);

          foreach (var ws_fd2 in ws_fds)
            new_web_service_addresses.set (web_service2, ws_fd2);
        }

      /* Get the PersonaStore to save the key file */
      yield ((Kf.PersonaStore) this.store).save_key_file ();

      this._web_service_addresses = new_web_service_addresses;
      this.notify_property ("web-service-addresses");
    }

  /**
   * Create a new persona.
   *
   * Create a new persona for the {@link PersonaStore} `store`, representing
   * the Persona given by the group `uid` in the key file `key_file`.
   */
  public Persona (string id, Folks.PersonaStore store)
    {
      var iid = store.id + ":" + id;
      var uid = this.build_uid ("key-file", store.id, id);

      Object (display_id: id,
              iid: iid,
              uid: uid,
              store: store,
              is_user: false);
    }

  construct
    {
      debug ("Adding key-file Persona '%s' (IID '%s', group '%s')", this.uid,
          this.iid, this.display_id);

      this._im_addresses = new HashMultiMap<string, ImFieldDetails> (
          null, null,  AbstractFieldDetails<string>.hash_static,
           AbstractFieldDetails<string>.equal_static);
      this._web_service_addresses =
        new HashMultiMap<string, WebServiceFieldDetails> (
            null, null,
             AbstractFieldDetails<string>.hash_static,
             AbstractFieldDetails<string>.equal_static);

      /* Load the IM addresses from the key file */
      unowned KeyFile key_file = ((Kf.PersonaStore) this.store).get_key_file ();

      try
        {
          var keys = key_file.get_keys (this.display_id);
          foreach (unowned string key in keys)
            {
              /* Alias */
              if (key == "__alias")
                {
                  this._alias = key_file.get_string (this.display_id, key);

                  if (this._alias == null)
                    {
                      this._alias = "";
                    }

                  debug ("    Loaded alias '%s'.", this._alias);
                  continue;
                }

              /* Web service addresses */
              var decomposed_key = key.split(".", 2);
              if (decomposed_key.length == 2 &&
                  decomposed_key[0] == "web-service")
                {
                  unowned string web_service = decomposed_key[1];
                  var web_service_addresses = key_file.get_string_list (
                      this.display_id, web_service);

                  foreach (var web_service_address in web_service_addresses)
                    {
                      this._web_service_addresses.set (web_service,
                          new WebServiceFieldDetails (web_service_address));
                    }

                  continue;
                }

              /* IM addresses */
              unowned string protocol = key;
              var im_addresses = key_file.get_string_list (
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

                  var im_fd = new ImFieldDetails (address);
                  this._im_addresses.set (protocol, im_fd);
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

              foreach (var im_fd in im_addresses)
                  callback (protocol + ":" + im_fd.value);
            }
        }
      else if (prop_name == "web-service-addresses")
        {
          foreach (var web_service in this.web_service_addresses.get_keys ())
            {
              var web_service_addresses =
                  this._web_service_addresses.get (web_service);

              foreach (var ws_fd in web_service_addresses)
                  callback (web_service + ":" + ws_fd.value);
            }
        }
      else
        {
          /* Chain up */
          base.linkable_property_to_links (prop_name, callback);
        }
    }
}
