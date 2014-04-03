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

/**
 * A test case for the key-file backend, which is configured as the
 * primary store and as the only backend allowed.
 */
public class KfTest.TestCase : Folks.TestCase
{
  /**
   * The key-file test backend.
   *
   * For compatibility with Folks' existing tests' assumptions, this
   * class creates this object but does not call its set_up() or
   * tear_down() methods.
   *
   * FIXME: ideally this should be per-test, created in set_up(),
   * and torn down in tear_down(). This would require making it nullable.
   */
  public KfTest.Backend kf_backend;

  public TestCase (string name)
    {
      base (name);

      this.kf_backend = new KfTest.Backend ();

      Environment.set_variable ("FOLKS_BACKENDS_ALLOWED", "key-file", true);
      Environment.set_variable ("FOLKS_PRIMARY_STORE", "key-file", true);
    }

  public override void tear_down ()
    {
      /* Ensure that all pending key file operations (e.g. saving the key file)
       * are complete.
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
