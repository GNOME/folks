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
 * Authors:
 *      Travis Reitter <travis.reitter@collabora.co.uk>
 *      Simon McVittie <simon.mcvittie@collabora.co.uk>
 */

public class TpfTest.TestCase : Folks.TestCase
{
  public KfTest.Backend? kf_backend = null;
  public TpTests.Backend? tp_backend = null;
  public void *account_handle = null;

  public virtual bool use_keyfile_too
    {
      get
        {
          return false;
        }
    }

  public TestCase (string name)
    {
      base (name);

      this.create_kf_backend ();
      this.create_tp_backend ();
    }

  public virtual void create_kf_backend ()
    {
      if (use_keyfile_too)
        this.kf_backend = new KfTest.Backend ();
    }

  public virtual void create_tp_backend ()
    {
      this.tp_backend = new TpTests.Backend ();
    }

  public override void set_up ()
    {
      base.set_up ();
      this.set_up_tp ();
      this.set_up_kf ();
    }

  public virtual void set_up_tp ()
    {
      if (this.tp_backend != null)
        {
          var tp_backend = (!) this.tp_backend;

          tp_backend.set_up ();
          this.account_handle = tp_backend.add_account ("protocol",
              "me@example.com", "cm", "account");
        }
    }

  public virtual void set_up_kf ()
    {
      if (this.kf_backend != null)
        ((!) this.kf_backend).set_up ("");
    }

  public override void tear_down ()
    {
      if (this.tp_backend != null)
        {
          var tp_backend = (!) this.tp_backend;

          if (this.account_handle != null)
            {
              tp_backend.remove_account (account_handle);
              this.account_handle = null;
            }

          tp_backend.tear_down ();
        }

      if (this.kf_backend != null)
        {
          ((!) this.kf_backend).tear_down ();
        }

      base.tear_down ();
    }
}

public class TpfTest.MixedTestCase : TpfTest.TestCase
{
  public override bool use_keyfile_too
    {
      get
        {
          return true;
        }
    }

  public MixedTestCase (string name)
    {
      base (name);
    }
}
