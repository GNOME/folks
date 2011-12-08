/*
 * Copyright (C) 2011 Collabora Ltd.
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
 * Authors: Guillaume Desmottes <guillaume.desmottes@collabora.co.uk>
 */

using Gee;
using Folks;

public class InitTests : Folks.TestCase
{
  private KfTest.Backend _kf_backend;
  private TpTest.Backend _tp_backend;
  private int _test_timeout = 5;

  public InitTests ()
    {
      base ("Init");

      this._kf_backend = new KfTest.Backend ();
      this._tp_backend = new TpTest.Backend ();

      /* Set up the tests */
      this.add_test ("looped", this.test_looped);
    }

  public override void set_up ()
    {
      this._tp_backend.set_up ();
    }

  public override void tear_down ()
    {
      this._tp_backend.tear_down ();
    }

  /* Prepare a load of aggregators in a tight loop, without waiting for any of
   * the prepare() calls to finish. Since the aggregators share a common
   * BackendStore, this tests the mutual exclusion of prepare() methods in the
   * backends. See: bgo#665728. */
  public void test_looped ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      this._kf_backend.set_up ("");

      void* account1_handle = this._tp_backend.add_account ("protocol",
          "me@example.com", "cm", "account");
      void* account2_handle = this._tp_backend.add_account ("protocol",
          "me2@example.com", "cm", "account2");

      /* Wreak havoc. */
      for (uint i = 0; i < 10; i++)
        {
          var aggregator = new IndividualAggregator ();
          aggregator.prepare (); /* Note: We don't yield for this to complete */
          aggregator = null;
        }

      /* Kill the main loop after a few seconds. */
      Timeout.add_seconds (this._test_timeout, () =>
        {
          main_loop.quit ();
          return false;
        });

      main_loop.run ();

      /* Clean up for the next test */
      this._tp_backend.remove_account (account2_handle);
      this._tp_backend.remove_account (account1_handle);
      this._kf_backend.tear_down ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new InitTests ().get_suite ());

  Test.run ();

  return 0;
}
