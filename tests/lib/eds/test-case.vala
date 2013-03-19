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
 * FIXME: For now, this relies on running under with-session-bus-eds.sh
 * with FOLKS_BACKEND_PATH set.
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
      /* This variable is set in the same place as the various variables we
       * care about for sandboxing purposes, like XDG_CONFIG_HOME and
       * DBUS_SESSION_BUS_ADDRESS. */
      if (Environment.get_variable ("FOLKS_TESTS_SANDBOXED_DBUS")
          != "eds")
        error ("e-d-s tests must be run in a private D-Bus session " +
            "with e-d-s services");

      base (name);

      Environment.set_variable ("FOLKS_BACKENDS_ALLOWED", "eds", true);
      Environment.set_variable ("FOLKS_PRIMARY_STORE", "eds:local://test",
          true);
    }

  public override string? create_transient_dir ()
    {
      /* Don't do anything. We're currently relying on
       * being wrapped in with-session-bus-eds.sh. */
      return null;
    }

  public override void private_bus_up ()
    {
      /* Don't do anything. We're currently relying on
       * being wrapped in with-session-bus-eds.sh. */
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

      base.tear_down ();
    }
}
