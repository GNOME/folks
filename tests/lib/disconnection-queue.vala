/* disconnection-queue.vala - disconnect signals automagically
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

public class Folks.DisconnectionQueue : Object
{
  [Compact]
  private class _Connection
    {
      internal weak Object obj;
      internal ulong id;

      internal _Connection (Object obj, ulong id)
        {
          this.obj = obj;
          this.id = id;
        }
    }

  private GenericArray<_Connection> _conns;

  public DisconnectionQueue ()
    {
      this._conns = new GenericArray<_Connection> ();
    }

  public void push (Object obj, ulong id)
    {
      return_if_fail (id != 0);

      this._conns.add (new _Connection (obj, id));
    }

  public void drain ()
    {
      var conns = this._conns;
      this._conns = new GenericArray<_Connection> ();

      for (uint i = 1; i <= conns.length; i++)
        {
          unowned _Connection conn = conns[conns.length - i];

          if (conn.obj != null && conn.id != 0)
            ((!) conn.obj).disconnect (conn.id);
        }
    }

  ~DisconnectionQueue ()
    {
      this.drain ();
    }
}
