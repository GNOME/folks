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

public class EdsTest.TestCase : Folks.TestCase
{
  public EdsTest.Backend? eds_backend = null;

  public TestCase (string name)
    {
      base (name);

      Environment.set_variable ("FOLKS_BACKENDS_ALLOWED", "eds", true);
      Environment.set_variable ("FOLKS_PRIMARY_STORE", "eds:local://test",
          true);
    }

  public override void set_up ()
    {
      base.set_up ();
      this.create_backend ();
      this.configure_primary_store ();
    }

  public virtual void create_backend ()
    {
      this.eds_backend = new EdsTest.Backend ();
      ((!) this.eds_backend).set_up ();
    }

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
