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
 * Authors: Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *
 */

using Folks;
using Gee;

public class ChangePrimaryStoreTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private EdsTest.Backend _eds_backend;
  private EdsTest.Backend _eds_backend_other;
  private IndividualAggregator _aggregator;
  private Folks.PersonaStore _pstore1;
  private Folks.PersonaStore _pstore2;
  private bool _new_primary_store_found;

  public ChangePrimaryStoreTests ()
    {
      base ("ChangePrimaryStoreTests");

      this._eds_backend = new EdsTest.Backend ();
      this._eds_backend.address_book_uri = "system";
      this._eds_backend_other = new EdsTest.Backend ();
      this._eds_backend_other.address_book_uri = "other";

      this.add_test ("test primary store changes in the IndividualAggregator",
          this.test_change_primary_store);
    }

  public override void set_up ()
    {
      Environment.unset_variable ("FOLKS_PRIMARY_STORE");
      this._eds_backend.set_up (true);
      this._eds_backend_other.set_up ();
    }

  public override void tear_down ()
    {
      this._eds_backend.tear_down ();
      this._eds_backend_other.tear_down ();
    }

  public void test_change_primary_store ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._new_primary_store_found = false;

      this._test_change_primary_store ();

      var timer_id = Timeout.add_seconds (8, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._new_primary_store_found);

      GLib.Source.remove (timer_id);
      this._aggregator = null;
      this._main_loop = null;
    }

  private async void _test_change_primary_store ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = new IndividualAggregator ();
      try
        {
          yield this._aggregator.prepare ();

          this._pstore1 = this._get_persona_store (store, "system");
          this._pstore2 = this._get_persona_store (store, "other");

          assert (this._pstore1 != null);
          assert (this._pstore2 != null);

          assert (this._aggregator.primary_store == this._pstore1);

          this._aggregator.notify["primary-store"].connect (
              this._primary_store_cb);

          this._eds_backend_other.set_as_default ();
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }
    }

  private PersonaStore? _get_persona_store (BackendStore store, string store_id)
    {
      PersonaStore? pstore = null;
      foreach (var backend in store.enabled_backends.values)
        {
          pstore = backend.persona_stores.get (store_id);
          if (pstore != null)
            break;
        }
      return pstore;
    }

  private void _primary_store_cb (Object ia_obj, ParamSpec ps)
    {
      IndividualAggregator ia = (IndividualAggregator) ia_obj;

      if (ia.primary_store == this._pstore2)
        {
          this._new_primary_store_found = true;
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new ChangePrimaryStoreTests ().get_suite ());

  Test.run ();

  return 0;
}
