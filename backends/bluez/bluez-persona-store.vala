/*
 * Copyright (C) 2010-2013 Collabora Ltd.
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
 *          Arun Raghavan <arun.raghavan@collabora.co.uk>
 *          Jeremy Whiting <jeremy.whiting@collabora.com>
 *          Simon McVittie <simon.mcvittie@collabora.co.uk>
 *          Gustavo Padovan <gustavo.padovan@collabora.co.uk>
 *          Matthieu Bouron <matthieu.bouron@collabora.com>
 *          Philip Withnall <philip.withnall@collabora.co.uk>
 *
 * Based on kf-persona-store.vala by:
 *       Travis Reitter <travis.reitter@collabora.co.uk>
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;
using Gee;
using Folks;
using Folks.Backends.BlueZ;
using org.bluez;

/* FIXME: Once we depend on gettext 0.18.3, translatable strings can once more
 * be split over multiple lines without breaking the .po file. */

/**
 * A persona store which is associated with a single BlueZ PBAP server (i.e.
 * one {@link PersonaStore} per device). It will create a {@link Persona} for
 * each contact on the device.
 *
 * Since large contact lists can take a long time to download in full (on the
 * order of 1s per 10 contacts), contacts are downloaded in two phases:
 * # Phase 1 downloads all non-PHOTO data. This is very fast (on the order of
 * 1s per 400 contacts)
 * # Phase 2 downloads all PHOTO data for those contacts. This is slow, but
 * happens later, in the background.
 *
 * Subsequent download attempts happen on an exponentially increasing interval,
 * up to a limit (once this limit is reached, updates occur on a regular
 * interval; the linear region). Download attempts repeat indefinitely unless a
 * certain number of consecutive attempts end in failure. See the documentation
 * for {@link _schedule_update_contacts} for details.
 *
 * @since 0.9.6
 */
public class Folks.Backends.BlueZ.PersonaStore : Folks.PersonaStore
{
  private HashMap<string, Persona> _personas;
  private Map<string, Persona> _personas_ro;
  private bool _is_prepared = false;
  private bool _prepare_pending = false;
  private bool _is_quiescent = false;

  private static string[] _always_writeable_properties = {};

  private org.bluez.obex.Client _obex_client;
  private string _object_path;
  private Device _device;
  private string _display_name;

  /* Non-null iff an _update_contacts() call is in progress. */
  private Cancellable? _update_contacts_cancellable = null;
  /* Non-0 iff an _update_contacts() call is scheduled. */
  private uint _update_contacts_id = 0;
  private bool _photos_up_to_date = true;
  /* Counter of the number of _update_contacts() calls which have been
   * scheduled. */
  private uint _update_contacts_n = 0;
  /* Number of consecutive failures in _update_contacts(). */
  private uint _update_contacts_failures = 0;

  /* Parameters for calculating the timeout for repeated _update_contacts()
   * calls. See the documentation for _schedule_update_contacts() for more. */
  private const uint _TIMEOUT_MIN = 4 /* seconds */;
  private const uint _TIMEOUT_BASE = 2 /* seconds */;
  private const uint _TIMEOUT_MAX = 5 * 60 /* minutes */;

  /* Number of consecutive failures in _update_contacts() before we give up
   * completely and stop trying to update from the phone. */
  private const uint _MAX_CONSECUTIVE_FAILURES = 3;

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override string type_id { get { return BACKEND_NAME; } }

  /**
   * Whether this PersonaStore can add {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_add_personas}.
   *
   * @since 0.9.6
   */
  public override MaybeBool can_add_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore can set the alias of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_alias_personas}.
   *
   * @since 0.9.6
   */
  public override MaybeBool can_alias_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore can set the groups of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_group_personas}.
   *
   * @since 0.9.6
   */
  public override MaybeBool can_group_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore can remove {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_remove_personas}.
   *
   * @since 0.9.6
   */
  public override MaybeBool can_remove_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore has been prepared.
   *
   * See {@link Folks.PersonaStore.is_prepared}.
   *
   * @since 0.9.6
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * Whether this PersonaStore has reached a quiescent state.
   *
   * See {@link Folks.PersonaStore.is_quiescent}.
   *
   * @since 0.9.6
   */
  public override bool is_quiescent
    {
      get { return this._is_quiescent; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override string[] always_writeable_properties
    {
      get { return BlueZ.PersonaStore._always_writeable_properties; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override Map<string, Folks.Persona> personas
    {
      get { return this._personas_ro; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public new string display_name
    {
      /* FIXME: Folks.display_name should be abstract, and this should be
       * override. */
      get { return this._display_name; }
      construct { this._display_name = value; }
    }

  /**
   * Path of the D-Bus object backing this {@link PersonaStore}.
   *
   * This is the path of the BlueZ device object on D-Bus which provides the
   * contacts in this store.
   *
   * @since 0.9.6
   */
  public string object_path
    {
      get { return this._object_path; }
      construct { this._object_path = value; }
    }

  /**
   * Create a new PersonaStore.
   *
   * Create a new persona store to expose the {@link Persona}s provided by the
   * device with the given Bluetooth address.
   *
   * @param device the D-Bus object for the Bluetooth device.
   * @param object_path the D-Bus path of the object for the Bluetooth device
   * @param obex_client the D-Bus obex client object.
   *
   * @since 0.9.6
   */
  public PersonaStore (Device device, string object_path,
      org.bluez.obex.Client obex_client)
    {
      Object (id: device.address,
              object_path: object_path,
              display_name: device.alias);

      this._device = device;
      this._obex_client = obex_client;

      this.set_is_trusted (this._device.trusted);
    }

  construct
    {
      this._personas = new HashMap<string, Persona> ();
      this._personas_ro = this._personas.read_only_view;
    }

  /**
   * Load contacts from a file and update the persona store.
   *
   * Load contacts from a file identified by its {@link File} and update
   * the persona store accordingly. Contacts are stored in the file as a
   * sequence of vCards, separated by blank lines.
   *
   * If a contact already exists in the store, its properties will be updated
   * from the vCard; otherwise it will be added as a new contact to the store.
   * Contacts which are in the store and not in the vCard will be removed from
   * the store.
   *
   * If this throws an error, it guarantees to leave the store’s internal state
   * unchanged, but may change the state of {@link Persona}s in the store.
   *
   * @param file the file where the contacts are stored
   * @throws IOError if there was an error communicating with D-Bus
   * @throws Error if the given file couldn’t be read
   *
   * @since 0.9.6
   */
  private async void _update_contacts_from_file (File file) throws IOError
    {
      var added_personas = new HashSet<Persona> ();
      var removed_personas = new HashSet<Persona> ();
      var photos_up_to_date = true;

      debug ("Parsing contacts from file ‘%s’.", file.get_path ());

      /* Start with all personas being marked as removed, and then eliminate the
       * ones which are found in the vCard. */
      removed_personas.add_all (this._personas.values);

      try
        {
          var dis = new DataInputStream (file.read ());
          uint i = 0;
          string? line = null;
          StringBuilder vcard = new StringBuilder ();
          var vcard_without_photo = new StringBuilder ();

          /* For each vCard in the file create or update a Persona. */
          while ((line = yield dis.read_line_async ()) != null)
            {
              /* Ignore blank lines between vCards. */
              if (vcard.len == 0 && line.strip () == "")
                  continue;

              vcard.append (line);
              vcard.append_c ('\n');

              if (!line.has_prefix ("PHOTO:") && !line.has_prefix ("PHOTO;"))
                {
                  vcard_without_photo.append (line);
                  vcard_without_photo.append_c ('\n');
                }

              if (line.strip () == "END:VCARD")
                {
                  var card = new E.VCard.from_string (vcard.str);

                  /* The first vCard is always the user themselves. */
                  var is_user = (i == 0);

                  /* Construct the card’s IID. */
                  var iid_is_checksum = false;
                  string iid;

                  /* This prefers the ‘UID’ attribute from the vCard, if it’s
                   * available. However, it is not a required attribute, so many
                   * phones do not implement it; in those cases, fall back to a
                   * checksum of the vCard data itself. This means that whenever
                   * a contact’s properties change in the vCard its IID will
                   * change and hence the persona will be removed and re-added,
                   * but without stable UIDs this is unavoidable.
                   *
                   * Note that the checksum is always calculated from the vCard
                   * data *without* the photo. This hopefully ensures that IIDs
                   * from queries which do and do not include photos will
                   * match. */
                  var attribute = card.get_attribute ("UID");
                  if (attribute != null)
                    {
                      /* Try the UID attribute. */
                      iid = attribute.get_value_decoded ().str;
                    }
                  else
                    {
                      /* Fallback. */
                      iid =
                           Checksum.compute_for_string (ChecksumType.SHA1,
                               vcard_without_photo.str);
                      iid_is_checksum = true;
                    }

                  /* Create or update the persona. */
                  var persona = this._personas.get (iid);
                  if (persona == null)
                    {
                      persona =
                          new Persona (vcard.str, card, this, is_user, iid);
                      photos_up_to_date = false;
                    }
                  else
                    {
                      /* If the IID is a checksum and we found the persona in
                       * the store, that means their properties haven’t
                       * changed, so as an optimisation, don’t bother updating
                       * the Persona from the vCard in that case. */
                      if (iid_is_checksum == false ||
                          vcard_without_photo.len != vcard.len)
                        {
                          /* Note: This updates persona’s state, which could be
                           * left updated if we later throw an error. */
                          if (persona.update_from_vcard (card) == true)
                              photos_up_to_date = false;
                        }
                    }

                  if (removed_personas.remove (persona) == false)
                      added_personas.add (persona);

                  i++;
                  vcard.erase ();
                  vcard_without_photo.erase ();
                }
            }
        }
      catch (GLib.Error e1)
        {
          /* I/O error reading the file. */
          throw new IOError.FAILED (
              /* Translators: the parameter is an error message. */
              _("Error reading the transferred address book file: %s"),
              e1.message);
        }

      /* Now that all the I/O is done and no more errors can be thrown, update
       * the store’s internal state. */
      debug ("Finished parsing personas; now updating store state with %u " +
          "added personas and %u removed personas.", added_personas.size,
          removed_personas.size);

      foreach (var p in added_personas)
          this._personas.set (p.iid, p);
      foreach (var p in removed_personas)
          this._personas.unset (p.iid);

      this._photos_up_to_date = photos_up_to_date;

      if (added_personas.is_empty == false ||
          removed_personas.is_empty == false)
        {
          this._emit_personas_changed (added_personas, removed_personas);
        }
    }

  /**
   * Set the persona store's alias.
   *
   * This will be called in response to a property change sent to the Backend.
   *
   * @param alias the device’s new alias
   *
   * @since 0.9.6
   */
  internal void set_alias (string alias)
    {
      debug ("Device ‘%s’ (%s) changed alias to ‘%s’.", this._display_name,
          this._device.address, alias);

      this._display_name = alias;
      this.notify_property ("display-name");
    }

  /**
   * Set the persona store's trust level.
   *
   * This will be called in response to a property change sent to the Backend.
   *
   * Default to partial trust. BlueZ persona UIDs are built from a SHA1
   * of the contact’s vCard, which we believe can’t be maliciously edited
   * to corrupt linking.
   *
   * The trust for each device is manually set by the user in the BlueZ
   * interface on the computer.
   *
   * @param trusted ``true`` if the user trusts the device, ``false`` otherwise
   *
   * @since 0.9.6
   */
  internal void set_is_trusted (bool trusted)
    {
      debug ("Device ‘%s’ (%s) marked as %s.", this._device.alias,
          this._device.address, trusted ? "trusted" : "untrusted");

      this.trust_level =
          trusted ? PersonaStoreTrust.FULL : PersonaStoreTrust.PARTIAL;
    }

  /**
   * Set the persona store's connection state.
   *
   * This will be called in response to a property change sent to the Backend.
   *
   * If this throws an error, it guarantees to leave the store’s internal state
   * unchanged.
   *
   * @param connected ``true`` if the device is now connected, ``false``
   * otherwise
   *
   * @throws IOError if the operation was cancelled
   * (see {@link _update_contacts})
   * @throws PersonaStoreError if the contacts couldn’t be updated
   * (see {@link _update_contacts})
   *
   * @since 0.9.6
   */
  internal async void set_connection_state (bool connected)
      throws IOError, PersonaStoreError
    {
       if (connected == true)
        {
          debug ("Device ‘%s’ (%s) is connected.", this._device.alias,
              this._device.address);

          yield this._update_contacts (false);
        }
      else
        {
          debug ("Device ‘%s’ (%s) is disconnected.", this._device.alias,
              this._device.address);

          /* Cancel any ongoing or scheduled transfers. */
          this.cancel_updates ();
        }
    }

  /**
   * Create a new obex session for this Persona store.
   *
   * Create a new obex session for this Persona store if no previous session
   * already exists.
   *
   * @param obex_pbap return location for an OBEX PBAP proxy object
   * @returns the path of the OBEX session D-Bus object
   * @throws IOError if it can't connect to D-Bus
   * @throws DBusError if it can't create a new OBEX session
   *
   * @since 0.9.6
   */
  private async dynamic ObjectPath _new_obex_session (
      out org.bluez.obex.PhonebookAccess obex_pbap)
      throws DBusError, IOError
    {
      debug ("Creating a new OBEX session.");

      var args = new HashTable<string, Variant> (null, null);
      args["Target"] = "PBAP";

      var session_path = yield this._obex_client.create_session (this.id, args);

      debug ("    Got OBEX session path: %s", session_path);

      obex_pbap =
          yield Bus.get_proxy (BusType.SESSION, "org.bluez.obex", session_path);

      debug ("    Got OBEX PBAP proxy: %p", obex_pbap);

      return session_path;
    }

  /**
   * Remove the specified OBEX session from this persona store.
   *
   * Remove the specified OBEX session for this persona store and discard its
   * transfer.
   *
   * @param session_path the path of the OBEX session D-Bus object to remove
   *
   * @since 0.9.6
   */
  private async void _remove_obex_session (dynamic ObjectPath session_path)
    {
      try
        {
          yield this._obex_client.remove_session (session_path);
        }
      catch (IOError ie)
        {
          /* Ignore errors from closing or cancelling, or if the session has
           * disappeared already. */
          if (ie is IOError.CLOSED || ie is IOError.CANCELLED)
              return;
          if (ie is IOError.DBUS_ERROR &&
              ie.message.has_prefix ("GDBus.Error:org.freedesktop.DBus." +
                                     "Python.dbus.exceptions.DBusException: " +
                                     "('org.freedesktop.DBus.Mock.NameError'"))
            {
              /* Only used in unit tests. */
              return;
            }

          warning ("Couldn’t remove OBEX session ‘%s’: %s",
              session_path, ie.message);
        }
      catch (DBusError de)
        {
          warning ("Couldn’t remove OBEX session ‘%s’: %s",
              session_path, de.message);
        }
    }

  /**
   * Watch an OBEX transfer identified by its D-Bus path.
   *
   * This only returns once the transfer is complete (or has failed) and the
   * transfer object has been destroyed.
   *
   * If this throws an error, it guarantees to leave the store’s internal state
   * unchanged.
   *
   * @param path the D-Bus transfer object path to watch.
   * @param cancellable an optional {@link Cancellable} object to cancel the
   * transfer
   *
   * @throws IOError if the operation was cancelled, or if another failure
   * occurred (unavoidable; valac generates invalid C if we try to handle
   * IOError internally here)
   * @throws PersonaStoreError if the transfer failed
   *
   * @since 0.9.6
   */
  private async void _perform_obex_transfer (string path,
      Cancellable? cancellable = null)
      throws IOError, PersonaStoreError
    {
      org.bluez.obex.Transfer? transfer = null;

      try
        {
          /* Bail early if the transfer's already been cancelled. */
          if (cancellable != null)
              cancellable.set_error_if_cancelled ();

          /* Get an OBEX proxy for the transfer object. */
          transfer =
              yield Bus.get_proxy (BusType.SESSION, "org.bluez.obex", path);
          var transfer_proxy = (DBusProxy) transfer;

          var has_yielded = false;
          string? transfer_status = null;
          ulong signal_id;
          ulong cancellable_id = 0;

          /* Find the initial status, if it’s already been set. Otherwise it’ll
           * be null. */
          transfer_status = transfer.status;

          /* Set up the cancellable. */
          if (cancellable != null)
            {
              cancellable_id = cancellable.connect (() =>
                {
                  transfer_status = "error";
                  if (has_yielded == true)
                      this._perform_obex_transfer.callback ();
                });
            }

          /* There is no need to add a timeout here, as BlueZ already has one
           * implemented for if transactions take too long. */
          signal_id = transfer_proxy.g_properties_changed.connect (
              (changed, invalidated) =>
            {
              var property =
                  changed.lookup_value ("Status", VariantType.STRING);
              if (property == null)
                  return;

              var status = property.get_string ();
              transfer_status = status;

              if (status == "complete" || status == "error")
                {
                  /* Finished. Return to the yield. */
                  if (has_yielded == true)
                      this._perform_obex_transfer.callback ();
                }
              else if (status == "queued" || status == "active")
                {
                  /* Do nothing. */
                }
              else
                {
                  warning ("Unknown OBEX transfer status ‘%s’.", status);
                }
            });

          /* Yield until the above signal handler is called with a ‘success’ or
           * ‘error’ status. */
          if (transfer_status != "complete" && transfer_status != "error")
            {
              has_yielded = true;
              yield;
            }

          transfer_proxy.disconnect (signal_id);

          if (cancellable_id != 0)
              cancellable.disconnect (cancellable_id);

          /* Process the results: either success or error. */
          if (transfer_status == "complete")
            {
              string? filename = transfer.filename;
              if (filename == null)
                {
                  /* The Filename property is optional, so bail if it’s not
                   * available for whatever reason. */
                  throw new PersonaStoreError.STORE_OFFLINE (
                      /* Translators: the first parameter is the name of the
                       * failed transfer, and the second is a Bluetooth device
                       * alias. */
                      _("Error during transfer of the address book ‘%s’ from " +
                        "Bluetooth device ‘%s’."),
                      transfer.name, this._display_name);
                }

              var file = File.new_for_path ((!) filename);

              debug ("vCard’s filename for device ‘%s’ (%s): %s",
                  this._display_name, this.id, (!) filename);

              yield this._update_contacts_from_file (file);
            }
          else if (transfer_status == "error")
            {
              /* On cancellation, throw an IOError instead of a
               * PersonaStoreError. */
              if (cancellable != null)
                  cancellable.set_error_if_cancelled ();

              throw new PersonaStoreError.STORE_OFFLINE (
                  /* Translators: the first parameter is the name of the failed
                   * transfer, and the second is a Bluetooth device alias. */
                  _("Error during transfer of the address book ‘%s’ from Bluetooth device ‘%s’."),
                  transfer.name, this._display_name);
            }
          else
            {
              assert_not_reached ();
            }
        }
      finally
        {
          /* Reset the OBEX transfer and clear out the temporary file. Do this
           * without yielding because BlueZ should choose a different filename
           * next time (using mkstemp() or similar). */
          if (transfer != null && transfer.filename != null)
            {
              var file = File.new_for_path (transfer.filename);
              file.delete_async.begin (GLib.Priority.DEFAULT, null,
                  (o, r) =>
                {
                  try
                    {
                      file.delete_async.end (r);
                    }
                  catch (GLib.Error e1)
                    {
                      /* Ignore. */
                    }
                });
            }
        }
    }

  /**
   * Update contacts from this persona store.
   *
   * Update contacts from this persona store by initiating a new OBEX
   * transfer, unless one is already in progress. If a transfer is already in
   * progress, leave it running and return immediately.
   *
   * If this throws an error, it guarantees to leave the store’s internal state
   * unchanged, apart from scheduling a new update operation to happen in the
   * future. This will always happen, regardless of success or failure.
   *
   * @param download_photos whether to download photos
   * @throws IOError if the operation was cancelled
   * @throws PersonaStoreError if the contacts couldn’t be downloaded from the
   * device
   *
   * @since 0.9.6
   */
  private async void _update_contacts (bool download_photos)
      throws IOError, PersonaStoreError
    {
      dynamic ObjectPath? session_path = null;
      org.bluez.obex.PhonebookAccess? obex_pbap = null;
      var success = true;

      if (this._update_contacts_cancellable != null)
        {
          /* There’s an ongoing _update_contacts() call. Since downloading
           * the address book takes a long time (tens of seconds), we don’t
           * want to cancel the ongoing operation. Just return
           * immediately. */
          debug ("Not updating contacts due to ongoing update operation.");
          return;
        }

      var profiling = Internal.profiling_start ("updating BlueZ.PersonaStore (ID: %s) " +
          "contacts", this.id);

      debug ("Updating contacts.");

      try
        {

          string path;
          HashTable<string, Variant> props;

          this._update_contacts_cancellable = new Cancellable ();

          /* Set up an OBEX session. */
          try
            {
              session_path = yield this._new_obex_session (out obex_pbap);
            }
          catch (GLib.Error e1)
            {
              if (e1 is IOError.DBUS_ERROR &&
                  e1.message.has_suffix ("OBEX Connect failed with 0x43"))
                {
                  /* This error is sent when the user denies the computer access
                   * to the phone’s address book over Bluetooth, after accepting
                   * the pairing request. */
                  throw new PersonaStoreError.PERMISSION_DENIED (
                      _("Permission to access the address book on Bluetooth device ‘%s’ was denied by the user."),
                      this._device.alias);
                }

              throw new PersonaStoreError.STORE_OFFLINE (
                  /* Translators: the first parameter is a Bluetooth device
                   * alias, and the second is an error message. */
                  _("An OBEX address book transfer from device ‘%s’ could not be started: %s"),
                  this._device.alias, e1.message);
            }

          try
            {
              /* Select the phonebook object we want to download ie:
               * PB: phonebook for the saved contacts */
              obex_pbap.select ("int", "PB");

              /* Initiate a phone book transfer from the PSE server using a
               * plain string vCard format, transferring to a temporary file. */
              var phonebook_filter =
                  new HashTable<string, Variant> (null , null);
              phonebook_filter.insert ("Format", "Vcard30");
              if (download_photos == true)
                {
                  /* Download everything including the photo. */
                  phonebook_filter.insert ("Fields",
                      new Variant.strv ({
                          "UID", "N", "FN", "NICKNAME", "TEL", "URL", "EMAIL",
                          "PHOTO"
                      }));
                }
              else
                {
                  /* Download everything except the photo. */
                  phonebook_filter.insert ("Fields",
                      new Variant.strv ({
                          "UID", "N", "FN", "NICKNAME", "TEL", "URL", "EMAIL"
                      }));
                }

              obex_pbap.pull_all ("", phonebook_filter, out path, out props);
            }
          catch (GLib.Error e2)
            {
              throw new PersonaStoreError.STORE_OFFLINE (
                  /* Translators: the first parameter is a Bluetooth device
                   * alias, and the second is an error message. */
                  _("The OBEX address book transfer from device ‘%s’ failed: %s"),
                  this._device.alias, e2.message);
            }

          try
            {
              yield this._perform_obex_transfer (path,
                  this._update_contacts_cancellable);
            }
          catch (IOError e3)
            {
              if (e3 is IOError.CANCELLED)
                  throw e3;

              throw new PersonaStoreError.STORE_OFFLINE (
                  /* Translators: the first parameter is a Bluetooth device
                   * alias, and the second is an error message. */
                  _("Error during transfer of the address book from Bluetooth device ‘%s’: %s"),
                  this._display_name, e3.message);
            }
        }
      catch (IOError e4)
        {
          /* Used below. */
          success = false;
          throw e4;
        }
      catch (PersonaStoreError e5)
        {
          /* Used below. */
          success = false;
          throw e5;
        }
      finally
        {
          /* Tear down again. */
          if (session_path != null)
              this._remove_obex_session.begin (session_path);
          obex_pbap = null;

          this._update_contacts_cancellable = null;

          /* Track the number of consecutive failures. */
          if (success == true)
              this._update_contacts_failures = 0;
          else
              this._update_contacts_failures++;

          /* Schedule the next update. See the documentation for
           * _schedule_update_contacts() for details. */
          var new_download_photos =
              success == true && this._photos_up_to_date == false;
          this._schedule_update_contacts (new_download_photos);

          Internal.profiling_end ((owned) profiling);
        }
    }

  /**
   * Schedule the next call to {@link _update_contacts}.
   *
   * This calculates a suitable timeout value and schedules the next timeout
   * for updating the contacts.
   *
   * The update scheme is as follows:
   *  1. Download the contacts (without photos) as soon as connected to the
   *     phone.
   *  2. Schedule a second download attempt for a few seconds after the first
   *     one completes. If the first one completes successfully, this second
   *     download will include photos; otherwise, it won’t.
   *  3. Schedule subsequent download attempts for exponentially increasing
   *     timeouts, up to a maximum timeout (at which point the timeouts enter a
   *     linear region and repeat indefinitely). Subsequent download attempts
   *     will include photos only if they have not been successfully downloaded
   *     already, or if the previous download attempt caused other property
   *     changes in a persona (indicating that the address book has been edited
   *     on the phone).
   *  4. If updates fail a certain number of consecutive times, give up
   *     completely and leave the persona store in a prepared but empty
   *     quiescent state. Update attempts will only restart if the phone is then
   *     disconnected and reconnected.
   *
   * The rationale for this design is to:
   *  A. Allow for the user accidentally denying the first connection request on
   *     the phone, or not noticing it and it timing out. Attempting a second
   *     download after a timeout gives them an opportunity to fix the problem.
   *  B. If the user explicitly denies the connection request on the phone, the
   *     phone should remember this and automatically deny all future connection
   *     attempts until the consecutive failure limit is reached. The user
   *     shouldn’t be pestered to accept again.
   *  C. Watch for changes in the user’s address book and update the persona
   *     store accordingly. Unfortunately this has to be done by polling, since
   *     neither PBAP not OBEX itself support push notifications.
   *
   * @param download_photos whether to download photos
   *
   * @since 0.9.7
   */
  private void _schedule_update_contacts (bool download_photos)
    {
      /* Bail if a call is already scheduled. */
      if (this._update_contacts_id != 0)
          return;

      /* If there have been too many consecutive failures in _update_contacts(),
       * give up. */
      if (this._update_contacts_failures >=
              PersonaStore._MAX_CONSECUTIVE_FAILURES)
          return;

      /* Calculate the timeout (in milliseconds). If no divisor is applied, the
       * timeout should always be a whole number of seconds. */
      var timeout =
          uint.min (PersonaStore._TIMEOUT_MIN +
              (uint) Math.pow (PersonaStore._TIMEOUT_BASE,
                      this._update_contacts_n),
              PersonaStore._TIMEOUT_MAX);
      this._update_contacts_n++;

      timeout *= 1000;  /* convert from seconds to milliseconds */

      /* Allow the timeout to be tweaked for testing. */
      var divisor_str =
          Environment.get_variable ("FOLKS_BLUEZ_TIMEOUT_DIVISOR");
      if (divisor_str != null)
        {
          uint64 divisor;
          if (uint64.try_parse (divisor_str, out divisor) == true)
              timeout /= (uint) divisor;
        }

      /* Schedule the update. */
      SourceFunc fn = () =>
        {
          debug ("Scheduled update firing for BlueZ store ‘%s’.", this.id);

          /* Acknowledge the source has fired. */
          this._update_contacts_id = 0;

          this._update_contacts.begin (download_photos, (o, r) =>
            {
              try
                {
                  this._update_contacts.end (r);
                }
              catch (GLib.Error e4)
                {
                  /* Ignore cancellation. */
                  if (e4 is IOError.CANCELLED)
                      return;

                  /* Don't warn about offline stores. */
                  if (e4 is PersonaStoreError.STORE_OFFLINE)
                    {
                      debug ("Not updating persona store from BlueZ due to " +
                          "store being offline: %s", e4.message);
                    }
                  else
                    {
                      warning ("Error updating persona store from BlueZ: %s",
                          e4.message);
                    }
                }
            });

          return false;
        };

      if (timeout % 1000 == 0)
        {
          this._update_contacts_id =
              Timeout.add_seconds (timeout / 1000, (owned) fn);
        }
      else
        {
          this._update_contacts_id =
              Timeout.add (timeout, (owned) fn);
        }
    }

  /**
   * Cancel ongoing and scheduled updates from the device.
   *
   * This doesn't remove the store, but does cancel all ongoing updates and
   * future scheduled updates, in preparation for removing the store. This is
   * necessary to avoid the store maintaining a reference to itself (through the
   * closure for the next scheduled update) and thus never being finalised.
   *
   * @since 0.9.7
   */
  internal void cancel_updates ()
    {
      if (this._update_contacts_cancellable != null)
          this._update_contacts_cancellable.cancel ();
      if (this._update_contacts_id != 0)
        {
          Source.remove (this._update_contacts_id);
          this._update_contacts_id = 0;
        }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override async void prepare () throws PersonaStoreError
    {
      var profiling = Internal.profiling_start ("preparing BlueZ.PersonaStore (ID: %s)",
          this.id);

      if (this._is_prepared || this._prepare_pending)
        {
          return;
        }

      try
        {
          this._prepare_pending = true;

          /* Start downloading the contacts, regardless of the phone’s
           * connection state. If the phone is disconnected, the download should
           * force it to be connected. */
          try
            {
              yield this._update_contacts (false);
            }
          catch (IOError e1)
            {
              /* If this happens, the update operation was cancelled, which
               * means the phone spontaneously disconnected during the transfer.
               * Act as if the store has gone offline and mark preparation as
               * complete. */
              throw new PersonaStoreError.STORE_OFFLINE (
                  _("Bluetooth device ‘%s’ disappeared during address book transfer."),
                  this._device.alias);
            }
          finally
            {
              /* Done or failed. We always mark the persona store as prepared
               * and quiescent because of the limited data available to us from
               * BlueZ: we only have the Paired and Connected properties.
               * So a phone can be paired with the laptop, but its Bluetooth
               * can be turned off; or a phone can be paired with the laptop and
               * its Bluetooth turned on but no connection is active. In the
               * former case, we don't want to connect to the device (because
               * that will just fail). In the latter case, we do, because we
               * want to download the address book. However, BlueZ exposes no
               * information allowing differentiation of the two cases, so we
               * must always create a persona store for a paired device, and
               * must always try and connect. In order to prevent paired but
               * disconnected phones from causing quiescence to never be reached
               * (which may be a common occurrence), we always mark the stores
               * as prepared and quiescent.
               *
               * FIXME: Note that this will fit in well with caching, if that is
               * ever implemented in the BlueZ backend. Paired but disconnected
               * phones (with their Bluetooth off) can still have persona stores
               * on the laptop, and those persona stores can be populated by
               * cached personas until the phone is reconnected. */
              this._is_prepared = true;
              this.notify_property ("is-prepared");

              this._is_quiescent = true;
              this.notify_property ("is-quiescent");
            }
        }
      finally
        {
          this._prepare_pending = false;
        }

      Internal.profiling_end ((owned) profiling);
    }

  /**
   * Remove a {@link Persona} from the PersonaStore.
   *
   * See {@link Folks.PersonaStore.remove_persona}.
   *
   * @param persona the {@link Persona} to remove
   * @throws Folks.PersonaStoreError.READ_ONLY every time since the
   * BlueZ backend is read-only.
   *
   * @since 0.9.6
   */
  public override async void remove_persona (Folks.Persona persona)
      throws Folks.PersonaStoreError
    {
      throw new PersonaStoreError.READ_ONLY (
          "Personas cannot be removed from this store.");
    }

  /**
   * Add a new {@link Persona} to the PersonaStore.
   *
   * See {@link Folks.PersonaStore.add_persona_from_details}.
   *
   * @param details a map of keys to values giving the persona’s initial details
   * @throws Folks.PersonaStoreError.READ_ONLY every time since the
   * BlueZ backend is read-only.
   *
   * @since 0.9.6
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      throw new PersonaStoreError.READ_ONLY (
          "Personas cannot be added to this store.");
    }
}
