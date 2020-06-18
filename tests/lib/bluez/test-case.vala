/*
 * Copyright © 2013 Collabora Ltd.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 *      Philip Withnall <philip.withnall@collabora.co.uk>
 */

/**
 * A test case for the BlueZ backend, whose private D-Bus session contains the
 * necessary python-dbusmock instance to mock up BlueZ.
 *
 * @since 0.9.7
 */
public class BluezTest.TestCase : Folks.TestCase
{
  /**
   * A BlueZ backend, normally non-null between set_up() and tear_down().
   *
   * If this is non-null, the subclass is expected to have called
   * its set_up() method at some point before tear_down() is reached.
   * This usually happens in create_backend().
   */
  public BluezTest.Backend? bluez_backend = null;

  public TestCase (string name)
    {
      base (name);

      this.bluez_backend = new BluezTest.Backend ();

      Environment.set_variable ("FOLKS_BACKENDS_ALLOWED", "bluez", true);
      Environment.set_variable ("FOLKS_PRIMARY_STORE", "bluez", true);
      Environment.set_variable ("FOLKS_BLUEZ_TIMEOUT_DIVISOR", "100", true);
    }

  public override string create_transient_dir ()
    {
      var transient = base.create_transient_dir ();

      /* Evolution configuration directory. */
      var config_dir = Path.build_filename (transient, ".local", "share", "folks");

      if (GLib.DirUtils.create_with_parents (config_dir, 0700) != 0)
        error ("Unable to create ‘%s’: %s",
            config_dir, GLib.strerror (GLib.errno));

      return transient;
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.7
   */
  public override void set_up ()
    {
      base.set_up ();
      this.create_backend ();
      this.configure_primary_store ();
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.7
   */
  public override void private_bus_up ()
    {
      /* Set up service files for the python-dbusmock services. */
      this.create_dbusmock_service (BusType.SYSTEM, "org.bluez", "bluez5");
      this.create_dbusmock_service (BusType.SESSION, "org.bluez.obex",
          "bluez5-obex");

      base.private_bus_up ();
    }

  /**
   * Virtual method to create and set up the BlueZ backend.
   *
   * Called from set_up(); may be overridden to not create the backend,
   * or to create it but not set it up.
   *
   * Subclasses may chain up, but are not required to so.
   *
   * @since 0.9.7
   */
  public virtual void create_backend ()
    {
      this.bluez_backend = new BluezTest.Backend ();

      /* Allow any mock BlueZ devices we will create. */
      var devices_file_name =
          Path.build_filename (this.transient_dir, ".local", "share", "folks",
              "bluez-persona-stores.ini");
      var devices_file = ("[%s]\n" +
          "enabled=true\n").printf (((!) this.bluez_backend).primary_device_address);

      GLib.debug ("Creating device enabled file for ‘%s’ at %s", ((!) this.bluez_backend).primary_device_address, devices_file_name);
      try
        {
          FileUtils.set_contents (devices_file_name, devices_file);
        }
      catch (FileError e1)
        {
          error ("Error creating BlueZ backend configuration file ‘%s’: %s",
              devices_file_name, e1.message);
        }

      ((!) this.bluez_backend).set_up ();
    }

  /**
   * Virtual method to configure ``FOLKS_PRIMARY_STORE`` to point to
   * our //bluez_backend//.
   *
   * Subclasses may chain up, but are not required to so.
   *
   * @since 0.9.7
   */
  public virtual void configure_primary_store ()
    {
      /* By default, configure BlueZ as the primary store. */
      assert (this.bluez_backend != null);
      var config_val =
          "bluez:" + ((!) this.bluez_backend).primary_device_address;
      Environment.set_variable ("FOLKS_PRIMARY_STORE", config_val, true);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.7
   */
  public override void tear_down ()
    {
      if (this.bluez_backend != null)
        {
          ((!) this.bluez_backend).tear_down ();
          this.bluez_backend = null;
        }

      Environment.unset_variable ("FOLKS_PRIMARY_STORE");

      /* Ensure that all pending BlueZ operations are complete.
       *
       * FIXME: This should be eliminated and unprepare() should guarantee there
       * are no more pending Backend/PersonaStore events.
       *
       * https://bugzilla.gnome.org/show_bug.cgi?id=727700 */
      var context = MainContext.default ();
      while (context.iteration (false));

      base.tear_down ();
    }
}
