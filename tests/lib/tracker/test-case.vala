/* test-case.vala
 *
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
 *      Simon McVittie <simon.mcvittie@collabora.co.uk>
 */

public class TrackerTest.TestCase : Folks.TestCase
{
  public TrackerTest.Backend? tracker_backend = null;

  public TestCase (string name)
    {
      base (name);

      this.tracker_backend = new TrackerTest.Backend ();
    }

  public override void tear_down ()
    {
      if (this.tracker_backend != null)
        {
          ((!) this.tracker_backend).tear_down ();
        }

      base.tear_down ();
    }
}
