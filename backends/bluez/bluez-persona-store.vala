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
  private HashTable<string, Variant> _phonebook_filter;
  private string _object_path;
  private Device _device;
  private string _display_name;

  /* Non-null iff an _update_contacts() call is in progress. */
  private Cancellable? _update_contacts_cancellable = null;

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
  public override Map<string, Persona> personas
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
      this._phonebook_filter = new HashTable<string, Variant> (null , null);
      this._phonebook_filter.insert ("Format", "Vcard30");
      this._phonebook_filter.insert ("Fields",
          new Variant.strv ({
              "N", "FN", "NICKNAME", "TEL", "URL", "EMAIL", "PHOTO"
          }));
    }

  /**
   * Load contacts from a file and update the persona store.
   *
   * Load contacts from a file identified by its {@link File} and update
   * the persona store accordingly. Contacts are stored in the file as a
   * sequence of vCards, separated by blank lines.
   *
   * If this throws an error, it guarantees to leave the store’s internal state
   * unchanged.
   *
   * @param file the file where the contacts are stored
   * @param obex_pbap the current OBEX PBAP D-Bus proxy
   * @throws IOError if there was an error communicating with D-Bus
   * @throws DBusError if an error was returned over the bus
   * @throws Error if the given file couldn’t be read
   *
   * @since 0.9.6
   */
  private async void _update_contacts_from_file (File file,
      org.bluez.obex.PhonebookAccess obex_pbap)
      throws DBusError, IOError
    {
      var added_personas = new HashSet<Persona> ();

      /* Get the vCard listing data  where every entry
       * consists of a pair of strings containing the vCard
       * handle and the contact name. For example:
       *   "0.vcf" : "Me"
       *   "1.vcf" : "John"
       *
       * First entry corresponds to the user themselves.
       */
      var entries = obex_pbap.list (this._phonebook_filter);

      try
        {
          var dis = new DataInputStream (file.read ());
          uint i = 0;
          string? line = null;
          StringBuilder vcard = new StringBuilder ();

          /* For each vCard in the file create a new Persona */
          while ((line = yield dis.read_line_async ()) != null)
            {
              /* Ignore blank lines between vCards. */
              if (vcard.len == 0 && line.strip () == "")
                  continue;

              vcard.append (line);
              vcard.append_c ('\n');
              if (line.strip () == "END:VCARD")
                {
                  var entry = entries[i];

                  /* The first vCard is always the user themselves. */
                  var is_user = (i == 0);

                  var persona = new Persona (entry.vcard, entry.name,
                      vcard.str, this, is_user);
                  added_personas.add (persona);

                  i++;
                  vcard.erase ();
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
      foreach (var p in added_personas)
          this._personas.set (p.iid, p);

      if (added_personas.is_empty == false)
          this._emit_personas_changed (added_personas, null);
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

          yield this._update_contacts ();
        }
      else
        {
          debug ("Device ‘%s’ (%s) is disconnected.", this._device.alias,
              this._device.address);

          /* Cancel any ongoing transfers. */
          if (this._update_contacts_cancellable != null)
              this._update_contacts_cancellable.cancel ();
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
   * @param obex_pbap an OBEX PBAP proxy object to access the address book from
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
      org.bluez.obex.PhonebookAccess obex_pbap,
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
          if (transfer_status == null)
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
              string filename = transfer.filename;
              var file = File.new_for_path (filename);

              debug ("vCard’s filename for device ‘%s’ (%s): %s",
                  this._display_name, this.id, filename);

              yield this._update_contacts_from_file (file, obex_pbap);
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
      catch (DBusError e2)
        {
          throw new PersonaStoreError.STORE_OFFLINE (
              /* Translators: the first parameter is the name of the
               * failed transfer, the second is a Bluetooth device
               * alias, and the third is an error message. */
              _("Error during transfer of the address book ‘%s’ from Bluetooth device ‘%s’: %s"),
              transfer.name, this._display_name, e2.message);
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
   * unchanged.
   *
   * @throws IOError if the operation was cancelled
   * @throws PersonaStoreError if the contacts couldn’t be downloaded from the
   * device
   *
   * @since 0.9.6
   */
  private async void _update_contacts () throws IOError, PersonaStoreError
    {
      dynamic ObjectPath? session_path = null;
      org.bluez.obex.PhonebookAccess? obex_pbap = null;

      if (this._update_contacts_cancellable != null)
        {
          /* There’s an ongoing _update_contacts() call. Since downloading the
           * address book takes a long time (tens of seconds), we don’t want
           * to cancel the ongoing operation. Just return immediately. */
          debug ("Not updating contacts due to ongoing update operation.");
          return;
        }

      Internal.profiling_start ("updating BlueZ.PersonaStore (ID: %s) contacts",
          this.id);

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
              obex_pbap.pull_all ("", this._phonebook_filter, out path,
                  out props);
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
              yield this._perform_obex_transfer (path, obex_pbap,
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
      finally
        {
          /* Tear down again. */
          if (session_path != null)
              yield this._remove_obex_session (session_path);
          obex_pbap = null;

          this._update_contacts_cancellable = null;

          Internal.profiling_end ("updating BlueZ.PersonaStore (ID: %s) " +
              "contacts", this.id);
        }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override async void prepare () throws PersonaStoreError
    {
      Internal.profiling_start ("preparing BlueZ.PersonaStore (ID: %s)",
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
              yield this._update_contacts ();
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

      Internal.profiling_end ("preparing BlueZ.PersonaStore (ID: %s)", this.id);
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
