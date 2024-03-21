/*
 * Copyright (C) 2013 Collabora Ltd.
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

/* Specific mock interfaces for the BlueZ and OBEX services. */
namespace org
  {
    namespace bluez
      {
        /* Interface for the bluez5 python-dbusmock template. */
        [DBus (name = "org.bluez.Mock")]
        public interface Mock : Object
          {
            [DBus (name = "AddAdapter")]
            public abstract string add_adapter (string device_name,
                string system_name) throws GLib.Error;

            [DBus (name = "AddDevice")]
            public abstract string add_device (string adapter_device_name,
                string device_address, string alias) throws GLib.Error;

            [DBus (name = "PairDevice")]
            public abstract void pair_device (string adapter_device_name,
                string device_address) throws GLib.Error;

            [DBus (name = "BlockDevice")]
            public abstract void block_device (string adapter_device_name,
                string device_address) throws GLib.Error;
          }

        namespace obex
          {
            /* Interface for the bluez5-obex python-dbusmock template. */
            [DBus (name = "org.bluez.obex.Mock")]
            public interface Mock : Object
              {
                [DBus (name = "TransferCreated")]
                public signal void transfer_created (string path,
                    HashTable<string, Variant> filters,
                    string transfer_filename);
              }

            namespace transfer1
              {
                [DBus (name = "org.bluez.obex.transfer1.Mock")]
                public interface Mock : Object
                  {
                    [DBus (name = "UpdateStatus")]
                    public abstract void update_status (bool is_complete)
                        throws GLib.Error;
                  }
              }
          }
      }
  }

/**
 * Controller for a mock BlueZ backend.
 *
 * This contains control methods to instantiate and manipulate a mock BlueZ
 * service over D-Bus, for the purposes of testing the folks BlueZ backend.
 *
 * The mock service uses python-dbusmock, with control messages being sent to
 * ``*.Mock`` interfaces on the D-Bus objects. Those control interfaces are
 * exposed as {@link Backend.mock_bluez}, {@link Backend.mock_bluez_base},
 * {@link Backend.mock_obex} and {@link Backend.mock_obex_base}.
 *
 * @since 0.9.7
 */
public class BluezTest.Backend
{
  private org.bluez.Mock? _mock_bluez = null;
  private org.freedesktop.DBus.Mock? _mock_bluez_base = null;
  private org.bluez.obex.Mock? _mock_obex = null;
  private org.freedesktop.DBus.Mock? _mock_obex_base = null;

  /**
   * D-Bus proxy for the BlueZ-specific mock interface on the org.bluez object.
   *
   * @since 0.9.7
   */
  public org.bluez.Mock? mock_bluez
    {
      get { return this._mock_bluez; }
    }

  /**
   * D-Bus proxy for the dbusmock mock interface on the org.bluez object.
   *
   * @since 0.9.7
   */
  public org.freedesktop.DBus.Mock? mock_bluez_base
    {
      get { return this._mock_bluez_base; }
    }

  /**
   * D-Bus proxy for the BlueZ-specific mock interface on the org.bluez.obex
   * object.
   *
   * @since 0.9.7
   */
  public org.bluez.obex.Mock? mock_obex
    {
      get { return this._mock_obex; }
    }

  /**
   * D-Bus proxy for the dbusmock mock interface on the org.bluez.obex object.
   *
   * @since 0.9.7
   */
  public org.freedesktop.DBus.Mock? mock_obex_base
    {
      get { return this._mock_obex_base; }
    }

  /**
   * Default Bluetooth address used for the primary adapter.
   *
   * This is the address used for the primary Bluetooth adapter (``hci0``)
   * unless otherwise specified.
   *
   * @since 0.9.7
   */
  public string primary_device_address
    {
      get { return "00:00:00:00:00:00"; }
    }

  /**
   * Set up the mock D-Bus interfaces.
   *
   * This must be called before every different unit test. It creates D-Bus
   * proxies for the dbusmock objects, auto-launching python-dbusmock if
   * necessary.
   *
   * The required D-Bus service files must previously have been set up with the
   * buses which are in use. This is done in
   * {@link TestCase.create_transient_dir}.
   *
   * @since 0.9.7
   */
  public void set_up ()
    {
      /* Create proxies for the client code to use. This auto-starts the
       * services. Their service files are created in TestCase. */
      try
        {
          this._mock_bluez =
              Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", "/");
          this._mock_bluez_base =
              Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", "/");

          this._mock_obex =
              Bus.get_proxy_sync (BusType.SESSION, "org.bluez.obex", "/");
          this._mock_obex_base =
              Bus.get_proxy_sync (BusType.SESSION, "org.bluez.obex", "/");
        }
      catch (GLib.Error e1)
        {
          /* Tidy up. */
          this.tear_down ();

          error ("Error connecting to mock object: %s", e1.message);
        }
    }

  /**
   * Tear down the mock D-Bus interfaces.
   *
   * This must be called after every different unit test. It undoes
   * {@link Backend.set_up}, although the python-dbusmock processes are kept
   * around and reset, rather than being killed.
   *
   * @since 0.9.7
   */
  public void tear_down ()
    {
      /* Reset the python-dbusmock state. */
      try
        {
          this._mock_obex_base.reset ();
          this._mock_bluez_base.reset ();
        }
      catch (GLib.Error e1)
        {
          error ("Error resetting python-dbusmock state: %s", e1.message);
        }

      /* Remove the D-Bus proxies. The python-dbusmock instances will close by
       * themselves when the mock D-Bus buses are destroyed in
       * final_tear_down(). */
      this._mock_obex_base = null;
      this._mock_bluez_base = null;
      this._mock_obex = null;
      this._mock_bluez = null;
    }

  /**
   * Create a simple Bluetooth device with the given vCard.
   *
   * Create a new Bluetooth adapter (``hci0``) and a new Bluetooth device (with
   * address {@link Backend.primary_device_address}). Pair with the Bluetooth
   * device and simulate it having the given ``vcard`` (potentially containing
   * multiple whitespace-separated entries) as its address book.
   *
   * On error this function will abort the test.
   *
   * @param vcard series of vCards for the device’s address book
   * @param adapter_path optional return location for the adapter’s D-Bus object
   * path
   * @param device_path optional return location for the device’s D-Bus object
   * path
   * @return ID of the signal returning the vCard, as per
   * {@link Backend.set_simple_device_vcard}
   *
   * @since 0.9.7
   */
  public ulong create_simple_device_with_vcard (string vcard,
      out string? adapter_path = null, out string? device_path = null)
    {
      try
        {
          /* Set up a Bluetooth adapter and a single persona store. */
          adapter_path = this.mock_bluez.add_adapter ("hci0", "Test System");
          device_path =
              this.mock_bluez.add_device ("hci0", this.primary_device_address,
                  "My Phone");

          /* Pair with the phone. */
          this.mock_bluez.pair_device ("hci0", this.primary_device_address);

          /* Set the vCard to be returned for all transfers. */
          return this.set_simple_device_vcard (vcard);
        }
      catch (GLib.Error e1)
        {
          error ("Error setting up mock BlueZ device: %s", e1.message);
        }
    }

  /**
   * Set the vCard to be returned by a simple Bluetooth device.
   *
   * This sets the vCard which will be returned indefinitely. It returns a
   * signal ID which may be disconnected with:
   * {{{
   * this.mock_obex.disconnect (signal_id);
   * }}}
   * to prevent the vCard being returned in future.
   *
   * @param vcard series of vCards for the device’s address book
   * @return ID of the signal returning the vCard
   *
   * @since 0.9.7
   */
  public ulong set_simple_device_vcard (string vcard)
    {
      /* Wait for a transfer to be created. Skip activating it and go
       * straight to completion. */
      return this.mock_obex.transfer_created.connect ((p, f, v) =>
        {
          org.bluez.obex.transfer1.Mock proxy;

          try
            {
              FileUtils.set_contents (v, vcard);
            }
          catch (FileError e1)
            {
              error ("Error writing vCard transfer file ‘%s’: %s",
                  v, e1.message);
            }

          try
            {
              proxy =
                  Bus.get_proxy_sync (BusType.SESSION, "org.bluez.obex", p);
              proxy.update_status (true);
            }
          catch (GLib.Error e1)
            {
              error ("Error activating transfer: %s", e1.message);
            }
        });
    }
}
