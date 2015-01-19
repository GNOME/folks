/* test-case.vala
 *
 * Copyright © 2011 Collabora Ltd.
 * Copyright © 2013 Intel Corporation
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
 *      Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *      Simon McVittie <simon.mcvittie@collabora.co.uk>
 */

/**
 * A test case whose private D-Bus session contains the necessary daemons
 * for an Evolution address-book.
 *
 * The EDS daemons are started through D-Bus service activation in
 * {@link TestCase.private_bus_up}, and should automatically exit when the mock
 * D-Bus bus is torn down. All of their configuration and data storage is
 * isolated in a temporary directory which is unique per test run.
 *
 * The EDS daemons are only torn down in {@link TestCase.final_tear_down}, so
 * remain running between test cases in the same test binary. Their state is
 * soft-reset, but some state may be retained between test cases.
 */
public class EdsTest.TestCase : Folks.TestCase
{
  /**
   * An EDS backend, normally non-null between set_up() and tear_down().
   *
   * If this is non-null, the subclass is expected to have called
   * its set_up() method at some point before tear_down() is reached.
   * This usually happens in create_backend().
   */
  public EdsTest.Backend? eds_backend = null;

  public TestCase (string name)
    {
      base (name);

      Environment.set_variable ("FOLKS_BACKENDS_ALLOWED", "eds", true);
      Environment.set_variable ("FOLKS_PRIMARY_STORE", "eds:local://test",
          true);
    }

  public override string create_transient_dir ()
    {
      var transient = base.create_transient_dir ();

      /* Evolution configuration directory. */
      var config_dir = "%s/.config/evolution/sources".printf (transient);

      if (GLib.DirUtils.create_with_parents (config_dir, 0700) != 0)
        error ("unable to create '%s': %s",
            config_dir, GLib.strerror (GLib.errno));

      return transient;
    }

  public override void private_bus_up ()
    {
      base.private_bus_up ();

      /* Find out the libexec directory to use. */
      int exit_status = -1;
      string capture_stdout = null;

      try
        {
          Process.spawn_sync (null /* cwd */,
              { "pkg-config", "--variable=libexecdir", "libedata-book-1.2" },
              null /* envp */,
              SpawnFlags.SEARCH_PATH /* flags */,
              null /* child setup */,
              out capture_stdout,
              null /* do not capture stderr */,
              out exit_status);

          Process.check_exit_status (exit_status);
        }
      catch (GLib.Error e1)
        {
          error ("Error getting libexecdir from pkg-config: %s", e1.message);
        }

      var libexec = capture_stdout.strip ();

      /* Create service files for the Evolution binaries. */
      const string sources_services[] =
        {
          "org.gnome.evolution.dataserver.Sources3",
          "org.gnome.evolution.dataserver.Sources2",
          "org.gnome.evolution.dataserver.Sources1"
        };
      const string address_book_services[] =
        {
          "org.gnome.evolution.dataserver.AddressBook8",
          "org.gnome.evolution.dataserver.AddressBook7",
          "org.gnome.evolution.dataserver.AddressBook6",
          "org.gnome.evolution.dataserver.AddressBook5",
        };

      /* Source registry. */
      for (uint i = 0; i < sources_services.length; i++)
        {
          var service_file_name =
              Path.build_filename (this.transient_dir, "dbus-1", "services",
                  "evolution-source-registry-%u.service".printf (i));
          var service_file = ("[D-BUS Service]\n" +
              "Name=%s\n" +
              "Exec=%s/evolution-source-registry\n").printf (
                  sources_services[i], libexec);

          try
            {
              FileUtils.set_contents (service_file_name, service_file);
            }
          catch (FileError e2)
            {
              error ("Error creating D-Bus service file ‘%s’: %s",
                  service_file_name, e2.message);
            }
        }

      /* Address book factory. */
      for (uint i = 0; i < address_book_services.length; i++)
        {
          var service_file_name =
              Path.build_filename (this.transient_dir, "dbus-1", "services",
                  "evolution-addressbook-factory-%u.service".printf (i));
          var service_file = ("[D-BUS Service]\n" +
              "Name=%s\n" +
              "Exec=%s/evolution-addressbook-factory\n").printf (
                  address_book_services[i], libexec);

          try
            {
              FileUtils.set_contents (service_file_name, service_file);
            }
          catch (FileError e3)
            {
              error ("Error creating D-Bus service file ‘%s’: %s",
                  service_file_name, e3.message);
            }
        }
    }

  public override void set_up ()
    {
      base.set_up ();
      this.create_backend ();
      this.configure_primary_store ();
    }

  /**
   * Virtual method to create and set up the EDS backend.
   * Called from set_up(); may be overridden to not create the backend,
   * or to create it but not set it up.
   *
   * Subclasses may chain up, but are not required to so.
   */
  public virtual void create_backend ()
    {
      this.eds_backend = new EdsTest.Backend ();
      ((!) this.eds_backend).set_up ();
    }

  /**
   * Virtual method to configure ``FOLKS_PRIMARY_STORE`` to point to
   * our //eds_backend//.
   *
   * Subclasses may chain up, but are not required to so.
   */
  public virtual void configure_primary_store ()
    {
      /* By default, configure EDS as the primary store. */
      assert (this.eds_backend != null);
      string config_val = "eds:" + ((!) this.eds_backend).address_book_uid;
      Environment.set_variable ("FOLKS_PRIMARY_STORE", config_val, true);
    }

  public override void tear_down ()
    {
      if (this.eds_backend != null)
        {
          ((!) this.eds_backend).tear_down ();
          this.eds_backend = null;
        }

      Environment.unset_variable ("FOLKS_PRIMARY_STORE");

      /* Ensure that all pending operations are complete.
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
