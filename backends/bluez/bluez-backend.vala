/*
 * Copyright (C) 2012-2013 Collabora Ltd.
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
 *       Arun Raghavan <arun.raghavan@collabora.co.uk>
 *       Jeremy Whiting <jeremy.whiting@collabora.com>
 *       Simon McVittie <simon.mcvittie@collabora.co.uk>
 *       Gustavo Padovan <gustavo.padovan@collabora.co.uk>
 *       Matthieu Bouron <matthieu.bouron@collabora.com>
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 *
 * Based on kf-backend.vala by:
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;
using Gee;
using Folks;
using Folks.Backends.BlueZ;
using org.bluez;

extern const string BACKEND_NAME;

/**
 * A backend which loads {@link Persona}s from paired Bluetooth
 * devices using the Phonebook Access Protocol (PBAP) and presents them
 * using one {@link PersonaStore} per device.
 *
 * Each device can be in four states:
 *  - Unpaired and unconnected
 *  - Unpaired but connected
 *  - Paired but unconnected
 *  - Paired and connected
 *
 * The default state for a device is unpaired. The user must explicitly pair
 * their device and enable it using {@link Backend.enable_persona_store} or
 * {@link Backend.set_persona_stores} before folks will begin to use it — folks
 * ignores unpaired devices. Once a device is paired and enabled, folks will
 * attempt to do an OBEX PBAP transfer to copy the device’s address book; this
 * will automatically connect the device. After the transfer is complete, the
 * device will go back to being paired and unconnected.
 *
 * Note that by requiring that devices are explicitly enabled by calling
 * {@link Backend.set_persona_stores}, the BlueZ backend is empty by default
 * every time libfolks is loaded, until the client explicitly enables a device.
 * This may change in future, and the state of enabled devices may be retained
 * between runs.
 *
 * Every time the user explicitly connects to the device, folks will re-download
 * its address book. Currently, folks will not otherwise re-download it (i.e.
 * there are no change notifications and no polling).
 *
 * If a transfer is started from an unpaired device, the device will move to the
 * unpaired but connected state, and will pop up a notification asking the user
 * whether they want to pair to the computer. This should be avoided, and is why
 * folks ignores all unpaired devices.
 *
 * If a connection timeout occurs (e.g. because the user took too long to
 * approve a pairing request, or explicitly denied it), the device will become
 * disconnected again.
 *
 * If the phone user explicitly denies the phone’s request to share address book
 * data with the laptop (which happens after pairing is successful), creating an
 * OBEX transfer session will fail with an explicit error, which is handled in
 * the {@link PersonaStore}.
 *
 * No caching is implemented by libfolks at the moment, so the address book
 * will be downloaded every time folks starts up.
 *
 * Each device can be advertised by BlueZ as trusted or untrusted, a property
 * which is explicitly set by the user on the laptop (not on the device). Folks
 * will set the PersonaStore’s trust level appropriately, fully trusting devices
 * marked as trusted, and only partially trusting others.
 *
 * Each device can also be advertised by BlueZ as being blocked or non-blocked.
 * Blocked devices are not made available as persona stores, even if they are
 * paired with the laptop.
 *
 * @since 0.9.6
 */
public class Folks.Backends.BlueZ.Backend : Folks.Backend
{
  private bool _is_prepared = false;
  private bool _prepare_pending = false; /* used for unprepare() too */
  private bool _is_quiescent = false;
  /* Map from PersonaStore.id to PersonaStore. */
  private HashMap<string, PersonaStore> _persona_stores;
  private Map<string, PersonaStore> _persona_stores_ro;
  private DBusObjectManagerClient? _manager;  /* null before prepare() */
  private ulong _object_added_handler;
  private ulong _object_removed_handler;
  private ulong _properties_changed_handler;
  /* Map from device D-Bus object path to PersonaStore. */
  private HashMap<string, PersonaStore> _watched_devices;
  private org.bluez.obex.Client? _obex_client = null;
  /* Set of Bluetooth device addresses for the enabled devices. If a device
   * isn’t listed here, a PersonaStore will not be created for it. */
  private SmallSet<string> _enabled_devices;

  /**
   * Whether this Backend has been prepared.
   *
   * See {@link Folks.Backend.is_prepared}.
   *
   * @since 0.9.6
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * Whether this Backend has reached a quiescent state.
   *
   * See {@link Folks.Backend.is_quiescent}.
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
  public override string name { get { return BACKEND_NAME; } }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override Map<string, Folks.PersonaStore> persona_stores
    {
      get { return this._persona_stores_ro; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override void disable_persona_store (Folks.PersonaStore store)
    {
      var _store = store as BlueZ.PersonaStore;
      if (_store == null)
        return;

      debug ("Disabling persona store ‘%s’.", store.id);

      var device_address = store.id;  /* implicit assumption */
      this._enabled_devices.remove (device_address);
      this._save_enabled_devices.begin ((o, r) =>
        {
          this._save_enabled_devices.end (r);
        });

      if (!this._persona_stores.has_key (store.id))
        return;

      this._remove_persona_store ((!) _store, true, true);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override void enable_persona_store (Folks.PersonaStore store)
    {
      var _store = store as BlueZ.PersonaStore;
      if (_store == null)
        return;

      debug ("Enabling persona store ‘%s’.", store.id);

      var device_address = store.id;  /* implicit assumption */
      this._enabled_devices.add (device_address);
      this._save_enabled_devices.begin ((o, r) =>
        {
          this._save_enabled_devices.end (r);
        });

      /* See if any existing device objects correspond to the store. */
      this._refresh_devices.begin ((o, r) =>
        {
          this._refresh_devices.end (r);
        });
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override void set_persona_stores (Set<string>? storeids)
    {
      if (storeids == null)
        {
          /* Use all available devices. */
          var objs = this._manager.get_objects ();

          foreach (var obj in objs)
            {
              var device = obj.get_interface ("org.bluez.Device1") as Device;
              if (device == null)
                  continue;

              this._enabled_devices.add (device.address);
              this._add_device.begin (obj, (o, r) =>
                {
                  this._add_device.end (r);
                });
            }

          this._save_enabled_devices.begin ((o, r) =>
            {
              this._save_enabled_devices.end (r);
            });

          return;
        }

      /* Clear the set of enabled persona stores and re-populate it with only
       * the addresses from storeids. */
      this._enabled_devices.clear ();
      foreach (var store_id in storeids)
        {
          var device_address = store_id;  /* implicit assumption */
          this._enabled_devices.add (device_address);
        }

      this._save_enabled_devices.begin ((o, r) =>
        {
          this._save_enabled_devices.end (r);
        });

      this._refresh_devices.begin ((o, r) =>
        {
          this._refresh_devices.end (r);
        });
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public Backend ()
    {
      Object ();
    }

  construct
    {
      this._persona_stores = new HashMap<string, PersonaStore> ();
      this._persona_stores_ro = this._persona_stores.read_only_view;
      this._watched_devices = new HashMap<string, PersonaStore> ();
      this._enabled_devices = new SmallSet<string> ();
    }

  /**
   * Callback executed when a device property has changed.
   *
   * The callback is executed when a PropertiesChanged signal is received
   * on device. If the device is seen as connected it tries to update the
   * Persona store associated with it. If the device is seen as disconnected,
   * the OBEX session used by the {@link PersonaStore} is removed.
   *
   * @param obj_proxy D-Bus proxy for the object
   * @param iface_proxy D-Bus proxy for the interface on which the property
   * changed
   * @param changed the list of properties that have changed
   * @param invalidated the list of properties that have been invalidated
   *
   * @since 0.9.6
   */
  private void _device_properties_changed_cb (DBusObjectProxy obj_proxy,
      DBusProxy iface_proxy, Variant changed, string[] invalidated)
    {
      debug ("Properties changed on interface ‘%s’ of object ‘%s’:",
          iface_proxy.g_interface_name, obj_proxy.g_object_path);
      var iter = changed.iterator ();
      string key;
      Variant variant;
      while (iter.next ("{sv}", out key, out variant) == true)
          debug ("    %s", key);

      if (iface_proxy.g_interface_name != "org.bluez.Device1")
          return;

      var device = (Device) iface_proxy;

      /* UUIDs, Paired and Blocked properties. All affect whether we add or
       * remove a device/persona store. */
      var uuids = changed.lookup_value ("UUIDs", null);
      var paired = changed.lookup_value ("Paired", VariantType.BOOLEAN);
      var blocked = changed.lookup_value ("Blocked", VariantType.BOOLEAN);

      if (uuids != null || paired != null || blocked != null)
        {
          /* Sometimes the UUIDs property only changes a second or two after
           * the device first appears, so try adding the device again. */
          if (device.paired == true && device.blocked == false &&
              this._device_supports_pbap_pse (device))
            {
              this._add_device.begin (obj_proxy, (o, r) =>
                {
                  this._add_device.end (r);
                });
            }
          else
            {
              this._remove_device.begin (obj_proxy, (o, r) =>
                {
                  this._remove_device.end (r);
                });
            }
        }

      var store = this._persona_stores.get (device.address);

      if (store == null)
          return;

      /* Connected property. */
      var connected = changed.lookup_value ("Connected", VariantType.BOOLEAN);
      if (connected != null)
        {
          store.set_connection_state.begin (connected.get_boolean (), (o, r) =>
            {
              try
                {
                  store.set_connection_state.end (r);
                }
              catch (IOError e1)
                {
                  debug ("Changing connection state for device ‘%s’ (%s) " +
                      "was cancelled.", device.alias, device.address);
                }
              catch (PersonaStoreError e2)
                {
                  warning ("Error changing connection state for device " +
                      "‘%s’ (%s): %s", device.alias, device.address,
                      e2.message);
                }
            });
        }

      /* Trust level. */
      var trusted = changed.lookup_value ("Trusted", VariantType.BOOLEAN);
      if (trusted != null)
        {
          store.set_is_trusted (trusted.get_boolean ());
        }

      /* Alias. */
      var alias = changed.lookup_value ("Alias", VariantType.STRING);
      if (alias != null)
        {
          store.set_alias (alias.get_string ());
        }
    }

  /**
   * Add a new Persona store to this backend.
   *
   * Add a new Persona store associated with a device identified by
   * its address and alias. The function takes care of creating all
   * the D-Bus object and path required by the Personna store.
   *
   * @param device the D-Bus object for the Bluetooth device
   * @param path the path of the D-Bus device object.
   *
   * @since 0.9.6
   */
  private async void _add_persona_store (Device device, string path)
    {
      PersonaStore store =
          new BlueZ.PersonaStore (device, path, this._obex_client);

      /* Set the initial properties. */
      store.set_is_trusted (device.trusted);
      store.set_alias (device.alias);

      this._watched_devices[path] = store;
      this._persona_stores.set (store.id, store);

      store.removed.connect (this._persona_store_removed_cb);
      this.persona_store_added (store);
      this.notify_property ("persona-stores");
    }

  private void _remove_persona_store (PersonaStore store,
      bool remove_from_persona_stores, bool remove_from_watched_devices)
    {
      store.removed.disconnect (this._persona_store_removed_cb);

      /* Cancel all ongoing activity in the store and, critically, eliminate
       * the reflexive reference it holds. */
      store.cancel_updates ();

      this.persona_store_removed (store);

      if (remove_from_persona_stores == true)
          this._persona_stores.unset (store.id);
      if (remove_from_watched_devices == true)
          this._watched_devices.unset (store.object_path);

      this.notify_property ("persona-stores");
    }

  /**
   * Check if a device supports PSE (Phone Book Server Equipment.
   *
   * We assume that UUIDs won’t change after we initially see the device, so
   * don’t listen for changes to it.
   *
   * @param device the D-Bus device object
   * @return ``true`` if the device supports PSE, ``false`` otherwise.
   *
   * @since 0.9.6
   */
  private bool _device_supports_pbap_pse (Device device)
    {
      string[]? uuids = device.uuids;

      /* The UUIDs property is optional; if unset, it’s null. */
      if (uuids == null)
          return false;

      foreach (var uuid in (!) uuids)
        {
          /* Phonebook Access - PSE (Phone Book Server Equipment).
           * 0x112F is the pse part. */
          if (uuid == "0000112f-0000-1000-8000-00805f9b34fb")
              return true;
        }

      return false;
    }

  /**
   * Refresh the list of devices from D-Bus.
   *
   * Add any new devices which are on D-Bus but aren’t in the BlueZ backend.
   * This does not currently remove devices which have disappeared from D-Bus.
   *
   * @since 0.9.7
   */
  private async void _refresh_devices ()
    {
      var objs = this._manager.get_objects ();

      foreach (var obj in objs)
        {
          yield this._add_device (obj);
        }
    }

  /**
   * Add a device to the backend.
   *
   * @param _obj the device's D-Bus object
   *
   * @since 0.9.6
   */
  private async void _add_device (DBusObject obj)
    {
      debug ("Adding device at path ‘%s’.", obj.get_object_path ());

      var device = obj.get_interface ("org.bluez.Device1") as Device;
      if (device == null)
        {
          debug ("    Device doesn’t implement org.bluez.Device1 " +
              "interface. Ignoring.");
          return;
        }

      var path = obj.get_object_path ();

      if (this._watched_devices.has_key (path))
        {
          debug ("    Device already watched. Ignoring.");
          return;
        }

      if (device.paired == false)
        {
          debug ("    Device isn’t paired. Ignoring. Manually pair the device" +
              " to start downloading contacts.");
          return;
        }

      if (device.blocked == true)
        {
          debug ("    Device is blocked. Ignoring.");
          return;
        }

      if (!this._device_supports_pbap_pse (device))
        {
          debug ("    Doesn’t support PBAP PSE. Ignoring.");
          return;
        }

      if (!this._enabled_devices.contains (device.address))
        {
          debug ("    Device not in enabled devices list.");
          return;
        }

      yield this._add_persona_store (device, path);
    }

  /**
   * Remove a device from the backend.
   *
   * @param obj the device's D-Bus object
   *
   * @since 0.9.6
   */
  private async void _remove_device (DBusObject obj)
    {
      var path = obj.get_object_path ();
      PersonaStore? store = null;

      debug ("Removing device at ‘%s’.", path);

      if (this._watched_devices.unset (path, out store) == true)
        {
          debug ("Device ‘%s’ removed", path);
          this._remove_persona_store (store, true, false);
        }
    }

  private string _get_enabled_devices_key_file_path ()
    {
      var file = File.new_for_path (Environment.get_user_data_dir ());
      file = file.get_child ("folks");
      file = file.get_child ("bluez-persona-stores.ini");

      return file.get_path ();
    }

  /**
   * Save the list of enabled devices to a configuration file.
   *
   * @since 0.11.4
   */
  private async void _save_enabled_devices ()
    {
      var kf = new GLib.KeyFile ();
      var kf_path = this._get_enabled_devices_key_file_path ();

      foreach (var address in this._enabled_devices)
        kf.set_boolean (address, "enabled", true);

      debug ("Saving BlueZ enabled devices key file ‘%s’.", kf_path);

      try
        {
          var file = File.new_for_path (kf_path);
          var data = kf.to_data ();
          file.replace_contents (data.data,
              null, false, FileCreateFlags.PRIVATE,
              null, null);
        }
      catch (GLib.Error e)
        {
          warning ("Could not write updated BlueZ enabled devices key file " +
              "‘%s’: %s", kf_path, e.message);
        }
    }

  /**
   * Load the list of enabled devices from a configuration file.
   *
   * @since 0.11.4
   */
  private async void _load_enabled_devices ()
    {
      var kf = new GLib.KeyFile ();
      var kf_path = this._get_enabled_devices_key_file_path ();

      debug ("Loading BlueZ enabled devices key file ‘%s’.", kf_path);

      try
        {
          uint8[] contents;

          var file = File.new_for_path (kf_path);
          yield file.load_contents_async (null, out contents, null);
          unowned string contents_s = (string) contents;

          if (contents_s.length > 0)
            {
              kf.load_from_data (contents_s,
                  contents_s.length, KeyFileFlags.KEEP_COMMENTS);
            }
        }
      catch (GLib.Error e1)
        {
          if (!(e1 is IOError.NOT_FOUND))
            {
              warning ("The BlueZ enabled devices key file ‘%s’ could not be " +
                  "loaded: %s", kf_path, e1.message);
              return;
            }
          else
            {
              debug ("    Not found.");
            }
        }

      /* Update the set of enabled devices in memory. */
      this._enabled_devices.clear ();
      var groups = kf.get_groups ();
      foreach (var address in groups)
        {
          try
            {
              if (kf.get_boolean (address, "enabled"))
                {
                  debug ("    Enabling device ‘%s’", address);
                  this._enabled_devices.add (address);
                }
            }
          catch (GLib.KeyFileError e)
            {
              /* Ignore. */
            }
        }
    }

  private delegate Type TypeFunc ();

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override async void prepare () throws DBusError
    {
      var profiling = Internal.profiling_start ("preparing BlueZ.Backend");

      if (this._is_prepared || this._prepare_pending)
        {
          return;
        }

      /* In brief, this function:
       *  0. Loads the list of enabled devices — these are the Bluetooth devices
       *     which will be turned into PersonaStores (if they are connected,
       *     paired, support PBAP, etc.).
       *  1. Connects to org.bluez. If that’s not available, we assume BlueZ
       *     is not installed (or is not version 5), and throw an error, leaving
       *     the store unprepared.
       *  2. Connects to org.bluez.obex. Similarly, if that’s not available,
       *     we throw an error and leave the store unprepared.
       *  3. Connects to loads of signals and enumerates all the existing
       *     devices known to BlueZ. This cannot fail.
       */
      try
        {
          this._prepare_pending = true;
          this.freeze_notify ();

          /* Load the enabled devices. */
          yield this._load_enabled_devices ();

          try
            {
              this._manager =
#if VALA_0_36
                  yield new DBusObjectManagerClient.for_bus (BusType.SYSTEM,
#else
                  yield DBusObjectManagerClient.new_for_bus (BusType.SYSTEM,
#endif
                      DBusObjectManagerClientFlags.NONE, "org.bluez", "/",
                      /* DBusProxyTypeFunc: */
                      (manager, path, iface_name) =>
                        {
                          debug ("DBusProxyTypeFunc for path ‘%s’ and " +
                              "interface ‘%s’.", path, iface_name);

                          Type retval;

                          /* FIXME: Horrible hack to grab the proxy object for
                           * org.bluez.Device (rather than the interface itself)
                           * from Vala. Vala generates C code for both, but we
                           * can’t normally access the proxy object.
                           *
                           * See:
                           * https://bugzilla.gnome.org/show_bug.cgi?id=710817
                           */
                          if (iface_name == "org.bluez.Device1")
                            {
                              var q =
                                  Quark.from_string ("vala-dbus-proxy-type");
                              var dev_type = typeof (org.bluez.Device);
                              retval = ((TypeFunc) (dev_type.get_qdata (q))) ();
                            }
                          /* Fallback. */
                          else if (iface_name == null)
                              retval = typeof (DBusObjectProxy);
                          else
                              retval = typeof (DBusProxy);

                          debug ("    Returning: %s", retval.name ());

                          return retval;
                        });
            }
          catch (GLib.Error e1)
            {
              throw new DBusError.SERVICE_UNKNOWN (
                  _("No BlueZ 5 object manager running, so the BlueZ backend will be inactive. Either your BlueZ installation is too old (only version 5 is supported) or the service can’t be started."));
            }

          /* Set up the OBEX client which will be used for all transfers. */
          try
            {
              this._obex_client =
                  yield Bus.get_proxy (BusType.SESSION, "org.bluez.obex",
                      "/org/bluez/obex");
            }
          catch (GLib.Error e1)
            {
              throw new DBusError.SERVICE_UNKNOWN (
                  _("Error connecting to OBEX transfer daemon over D-Bus. Ensure BlueZ and obexd are installed."));
            }

          /* Successfully connected to both D-Bus services. Now connect up some
           * signal handlers. */
          this._object_added_handler =
              this._manager.object_added.connect ((obj) =>
                {
                  this._add_device.begin (obj, (o, r) =>
                    {
                      this._add_device.end (r);
                    });
                });

          this._object_removed_handler =
              this._manager.object_removed.connect ((obj) =>
                {
                  this._remove_device.begin (obj, (o, r) =>
                    {
                      this._remove_device.end (r);
                    });
                });

          this._properties_changed_handler =
              this._manager.interface_proxy_properties_changed.connect (
                  this._device_properties_changed_cb);

          /* Add all the existing device objects. */
          yield this._refresh_devices ();

          this._is_prepared = true;
          this.notify_property ("is-prepared");

          this._is_quiescent = true;
          this.notify_property ("is-quiescent");
        }
      finally
        {
          this.thaw_notify ();
          this._prepare_pending = false;
        }

      Internal.profiling_end ((owned) profiling);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.6
   */
  public override async void unprepare () throws GLib.Error
    {
      if (!this._is_prepared || this._prepare_pending == true)
        {
          return;
        }

      try
        {
          this._prepare_pending = true;

          if (this._manager != null)
            {
              this._manager.disconnect (this._object_added_handler);
              this._manager.disconnect (this._object_removed_handler);
              this._manager.disconnect (this._properties_changed_handler);
              this._manager = null;
              this._object_added_handler = 0;
              this._object_removed_handler = 0;
              this._properties_changed_handler = 0;
            }

          this._obex_client = null;

          this.freeze_notify ();

          var iter = this._persona_stores.map_iterator ();
          while (iter.next () == true)
            {
              this._remove_persona_store (iter.get_value (), false, true);
              iter.unset ();
            }

          this.notify_property ("persona-stores");

          this._is_quiescent = false;
          this.notify_property ("is-quiescent");

          this._is_prepared = false;
          this.notify_property ("is-prepared");

          this.thaw_notify ();
        }
      finally
        {
          this._prepare_pending = false;
        }
    }

  private void _persona_store_removed_cb (Folks.PersonaStore store)
    {
      this._remove_persona_store ((BlueZ.PersonaStore) store, true, true);
    }
}
