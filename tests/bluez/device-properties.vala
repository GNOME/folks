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
 * Authors: Philip Withnall <philip.withnall@collabora.co.uk>
 */

using Gee;
using Folks;
using BluezTest;

public class DevicePropertiesTests : BluezTest.TestCase
{
  public DevicePropertiesTests ()
    {
      base ("DeviceProperties");

      this.add_test ("device pairing", this.test_device_pairing);
      this.add_test ("blocked device", this.test_blocked_device);
      this.add_test ("device alias", this.test_device_alias);
    }

  /* Start with an unpaired Bluetooth device, and check that it’s not turned
   * into a PersonaStore. Then pair the device, and check that it is added as
   * a store. */
  public void test_device_pairing ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Set up a simple unpaired device. */
      try
        {
          this.bluez_backend.mock_bluez.add_adapter ("hci0", "Test System");
          this.bluez_backend.mock_bluez.add_device ("hci0",
              this.bluez_backend.primary_device_address, "My Phone");
        }
      catch (GLib.Error e1)
        {
          error ("Error setting up mock BlueZ device: %s", e1.message);
        }

      /* Set up its vCard in preparation. */
      this.bluez_backend.set_simple_device_vcard (
          "BEGIN:VCARD\n" +
          "VERSION:3.0\n" +
          "N:Jones;Pam;Mrs.\n" +
          "FN:Pam Jones\n" +
          "TEL:0123456789\n" +
          "END:VCARD\n");

      /* Set up the aggregator and wait until either quiescence, or the test
       * times out and fails. Unset the primary store to prevent a warning. */
      Environment.set_variable ("FOLKS_PRIMARY_STORE", "", true);

      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_quiescence.begin (aggregator,
          (o, r) =>
        {
          try
            {
              TestUtils.aggregator_prepare_and_wait_for_quiescence.end (r);
            }
          catch (GLib.Error e2)
            {
              error ("Error preparing aggregator: %s", e2.message);
            }

          main_loop.quit ();
        });

      TestUtils.loop_run_with_timeout (main_loop);

      var real_backend =
          aggregator.backend_store.dup_backend_by_name ("bluez");

      /* Check there are no individuals and no persona stores. */
      assert (aggregator.individuals.size == 0);
      assert (real_backend.persona_stores.size == 0);

      /* Wait for a signal about an added persona store. */
      TestUtils.aggregator_wait_for_individuals.begin (aggregator,
          {"Pam Jones"}, {}, (o, r) =>
        {
          TestUtils.aggregator_wait_for_individuals.end (r);
          main_loop.quit ();
        });

      /* Pair the device. */
      try
        {
          this.bluez_backend.mock_bluez.pair_device ("hci0",
              this.bluez_backend.primary_device_address);
        }
      catch (GLib.Error e4)
        {
          error ("Error pairing mock BlueZ device: %s", e4.message);
        }

      TestUtils.loop_run_with_timeout (main_loop);
    }

  /* Start with a blocked Bluetooth device, and check it’s not made into a
   * PersonaStore. Then unblock the device and check a PersonaStore is created.
   * Then block the device again and check the PersonaStore is removed. */
  public void test_blocked_device ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Set up a simple paired but blocked device. */
      this.bluez_backend.create_simple_device_with_vcard (
          "BEGIN:VCARD\n" +
          "VERSION:3.0\n" +
          "N:Jones;Pam;Mrs.\n" +
          "FN:Pam Jones\n" +
          "TEL:0123456789\n" +
          "END:VCARD\n");

      try
        {
          this.bluez_backend.mock_bluez.block_device ("hci0",
              this.bluez_backend.primary_device_address);
        }
      catch (GLib.Error e1)
        {
          error ("Error blocking device: %s", e1.message);
        }

      /* Set up the aggregator and wait until either quiescence, or the test
       * times out and fails. Unset the primary store to prevent a warning. */
      Environment.set_variable ("FOLKS_PRIMARY_STORE", "", true);

      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_quiescence.begin (aggregator,
          (o, r) =>
        {
          try
            {
              TestUtils.aggregator_prepare_and_wait_for_quiescence.end (r);
            }
          catch (GLib.Error e2)
            {
              error ("Error preparing aggregator: %s", e2.message);
            }

          main_loop.quit ();
        });

      TestUtils.loop_run_with_timeout (main_loop);

      var real_backend =
          aggregator.backend_store.dup_backend_by_name ("bluez");

      /* Check there are no individuals and no persona stores. */
      assert (aggregator.individuals.size == 0);
      assert (real_backend.persona_stores.size == 0);

      /* Wait for a signal about an added persona store. */
      TestUtils.aggregator_wait_for_individuals.begin (aggregator,
          {"Pam Jones"}, {}, (o, r) =>
        {
          TestUtils.aggregator_wait_for_individuals.end (r);
          main_loop.quit ();
        });

      /* Unblock the device. */
      try
        {
          this.bluez_backend.mock_bluez.pair_device ("hci0",
              this.bluez_backend.primary_device_address);
        }
      catch (GLib.Error e4)
        {
          error ("Error blocking device: %s", e4.message);
        }

      TestUtils.loop_run_with_timeout (main_loop);

      /* Wait for a signal about a removed persona store. */
      TestUtils.aggregator_wait_for_individuals.begin (aggregator,
          {}, {"Pam Jones"}, (o, r) =>
        {
          TestUtils.aggregator_wait_for_individuals.end (r);
          main_loop.quit ();
        });

      /* Block the device again. */
      try
        {
          this.bluez_backend.mock_bluez.block_device ("hci0",
              this.bluez_backend.primary_device_address);
        }
      catch (GLib.Error e5)
        {
          error ("Error blocking device again: %s", e5.message);
        }

      TestUtils.loop_run_with_timeout (main_loop);

      /* Check there are no individuals and no persona stores. */
      assert (aggregator.individuals.size == 0);
      assert (real_backend.persona_stores.size == 0);
    }

  /* Test that changes of a device’s Alias property result in the PersonaStore’s
   * display-name being updated. */
  public void test_device_alias ()
    {
      /* Set up the backend. */
      string device_path = "";
      this.bluez_backend.create_simple_device_with_vcard (
          "BEGIN:VCARD\n" +
          "VERSION:3.0\n" +
          "N:Jones;Pam;Mrs.\n" +
          "FN:Pam Jones\n" +
          "TEL:0123456789\n" +
          "END:VCARD\n",
          null, out device_path);

      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_individuals_sync_with_timeout (
          aggregator, {"Pam Jones"});

      /* Check the PersonaStore’s alias. */
      var real_backend =
          aggregator.backend_store.dup_backend_by_name ("bluez");
      assert (real_backend.persona_stores.size == 1);

      var real_store =
          real_backend.persona_stores.get (
              this.bluez_backend.primary_device_address);

      /* FIXME: Have to get the display-name this way because
       * Folks.PersonaStore.display_name is not declared as abstract. */
      string display_name = "";
      real_store.get ("display-name", out display_name);
      assert (display_name == "My Phone");

      /* Change the device’s Alias and see if the display-name changes. */
      var main_loop = new GLib.MainLoop (null, false);
      real_store.notify["display-name"].connect ((p) =>
        {
          real_store.get ("display-name", out display_name);
          assert (display_name == "New Alias!");
          main_loop.quit ();
        });

      try
        {
          Device mock_device =
              Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", device_path);
          org.freedesktop.DBus.Mock mock =
              Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", device_path);

          var props = new HashTable<string, Variant> (str_hash, str_equal);
          props.insert ("Alias", "New Alias!");

          mock_device.alias = "New Alias!";
          mock.emit_signal ("org.freedesktop.DBus.Properties",
              "PropertiesChanged", "sa{sv}as",
              {
                "org.bluez.Device1",
                props,
                new Variant.array (VariantType.STRING, {})
              });
        }
      catch (GLib.Error e1)
        {
          error ("Error setting device alias: %s", e1.message);
        }

      TestUtils.loop_run_with_timeout (main_loop);
    }
}

/* Mini-copy of the org-bluez.vala file in the BlueZ backend. */
[DBus (name = "org.bluez.Device1")]
public interface Device : Object
  {
    [DBus (name = "Alias")]
    public abstract string alias { owned get; set; }
  }

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new DevicePropertiesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
