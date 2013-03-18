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
 *      Alban Crequy <alban.crequy@collabora.co.uk>
 *      Simon McVittie <simon.mcvittie@collabora.co.uk>
 */

public class LibsocialwebTest.TestCase : Folks.TestCase
{
  public LibsocialwebTest.Backend? lsw_backend = null;

  public TestCase (string name)
    {
      base (name);

      this.lsw_backend = new LibsocialwebTest.Backend ();
    }

  public override void set_up ()
    {
      base.set_up ();

      if (this.lsw_backend != null)
        {
          var lsw_backend = (!) this.lsw_backend;

          var main_loop = new GLib.MainLoop (null, false);

          this.lsw_backend.ready.connect (() =>
            {
              main_loop.quit ();
            });
          uint timer_id = Timeout.add_seconds (5, () =>
            {
              assert_not_reached ();
            });

          lsw_backend.set_up ();
          main_loop.run ();
          Source.remove (timer_id);
        }
    }

  public override void tear_down ()
    {
      if (this.lsw_backend != null)
        {
          ((!) this.lsw_backend).tear_down ();
        }

      base.tear_down ();
    }
}
