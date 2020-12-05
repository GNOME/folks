/*
 * Copyright (C) 2012 Collabora Ltd.
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
 * Authors: Jeremy Whiting <jeremy.whiting@collabora.com>
 *
 */

using Folks;
using Gee;

public class EnableDisableStoresTests : EdsTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private EdsTest.Backend? _eds_backend_other;
  private IndividualAggregator _aggregator;
  private uint _n_stores_removed;
  private uint _n_stores_added;
  private uint _n_stores_prepared;
  private BackendStore? _backend_store;

  public EnableDisableStoresTests ()
    {
      base ("EnableDisableStoresTests");

      this.add_test ("test enabling and disabling of PersonaStores",
          this.test_disabling_stores);
    }

  public override void set_up ()
    {
      base.set_up ();

      this._n_stores_removed = 0;
      this._n_stores_added = 0;
      this._n_stores_prepared = 0;
      this._backend_store = BackendStore.dup();

      this._eds_backend_other = new EdsTest.Backend ("other");
      this._eds_backend_other.set_up (false);

      /* We configure eds as the primary store */
      Environment.set_variable ("FOLKS_BACKEND_EDS_USE_ADDRESS_BOOKS",
                                (this.eds_backend.address_book_uid + ":" +
                                 this._eds_backend_other.address_book_uid),
                                true);
    }

  public override void tear_down ()
    {
      this._eds_backend_other.tear_down ();
      this._eds_backend_other = null;

      base.tear_down ();
    }

  public void test_disabling_stores ()
    {
      this._main_loop = new GLib.MainLoop (null, false);

      this._test_disabling_stores_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._n_stores_removed == 2);
      assert (this._n_stores_added == 2);
      assert (this._n_stores_prepared == 2);

      this._aggregator = null;
      this._main_loop = null;
    }

  private async void _test_disabling_stores_async ()
    {
      yield this._backend_store.prepare ();
      this._aggregator = IndividualAggregator.dup ();
      try
        {
          yield this._backend_store.load_backends ();

          var backend = this._backend_store.enabled_backends.get ("eds");
          assert (backend != null);

          backend.persona_store_removed.connect (this._store_removed_cb);
          backend.persona_store_added.connect (this._store_added_cb);

          yield this._aggregator.prepare ();
          assert (this._aggregator.is_prepared);

          var pstore = this._get_store (this._backend_store,
              this.eds_backend.address_book_uid);
          assert (pstore != null);

          var pstore2 = this._get_store (this._backend_store,
              this._eds_backend_other.address_book_uid);
          assert (pstore2 != null);

          backend.disable_persona_store (pstore);
          backend.disable_persona_store (pstore2);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }
    }

  private PersonaStore? _get_store (BackendStore store, string store_id)
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

  private void _store_removed_cb (
       PersonaStore store)
    {
      assert (store != null);
      debug ("store removed %s", store.id);
      this._n_stores_removed++;

      var backend = this._backend_store.enabled_backends.get ("eds");
      assert (backend != null);

      debug ("enabling store %s", store.id);
      backend.enable_persona_store (store);
    }

  private void _store_added_cb (PersonaStore store)
    {
      debug ("store added %s", store.id);
      this._n_stores_added++;

      store.notify["is-prepared"].connect (this._store_prepared_cb);

      if (this._n_stores_added == 2 && this._n_stores_prepared == 2)
        {
          this._main_loop.quit ();
        }
    }

  private void _store_prepared_cb (Object _store, ParamSpec pspec)
    {
      PersonaStore store = (PersonaStore) _store;

      debug ("store prepared %s", store.id);
      this._n_stores_prepared++;

      if (this._n_stores_added == 2 && this._n_stores_prepared == 2)
        {
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new EnableDisableStoresTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
