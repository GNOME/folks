/*
 * Copyright (C) 2013 Collabora Ltd.
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
 * Authors: Philip Withnall <philip.withnall@collabora.co.uk>
 */

using Gee;
using Folks;

public class PrimaryStoreChangesTests : DummyTest.TestCase
{
  private GLib.MainLoop _main_loop;
  /* null iff GSettings schema is not installed: */
  private Settings? _settings = null;

  public FolksDummy.PersonaStore second_persona_store;

  public PrimaryStoreChangesTests ()
    {
      base ("PrimaryStoreChangesTests");

      Environment.unset_variable ("FOLKS_PRIMARY_STORE");

      /* Set up the tests */
      this.add_test ("change primary-store setting",
          this.test_change_primary_store_setting);
    }

  public override void set_up ()
    {
      base.set_up ();

      this.configure_second_persona_store ();
      this.dummy_persona_store.update_trust_level (PersonaStoreTrust.FULL);
    }

  public override void tear_down ()
    {
      /* Release setting to avoid test failing on tear_down */
      if (this._settings != null)
        {
          this._settings.set_string ("primary-store", "dummy:dummy-store");
        }

      var persona_stores = new HashSet<FolksDummy.PersonaStore> ();
      persona_stores.add (this.second_persona_store);
      this.dummy_backend.unregister_persona_stores (persona_stores);

      this.second_persona_store = null;

      base.tear_down ();
    }

  public void configure_second_persona_store ()
    {
      string[] writable_properties =
      {
        Folks.PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES),
        Folks.PersonaStore.detail_key (PersonaDetail.PHONE_NUMBERS),
        null
      };

      /* Create a new persona store. */
      this.second_persona_store =
      new FolksDummy.PersonaStore ("dummy-store-1", "Dummy personas I",
          writable_properties);
      this.second_persona_store.persona_type = typeof (FolksDummy.FullPersona);

      /* Register it with the backend. */
      var persona_stores = new HashSet<FolksDummy.PersonaStore> ();
      persona_stores.add (this.second_persona_store);
      this.dummy_backend.register_persona_stores (persona_stores);
    }

  /* Test that when manually changing ::primary-store gsetting key, the
     IndividualAgreggator instance gets notified */
  public void test_change_primary_store_setting ()
    {
      /* Iff running uninstalled, the GSetting schema will not be available, and
       * this test cannot be run. */
      unowned string[] schemas = Settings.list_schemas ();
      if (!("org.freedesktopp.folks" in schemas))
        {
          return;
        }

      this._main_loop = new GLib.MainLoop (null, false);
      test_change_primary_store_setting_async.begin ();
      TestUtils.loop_run_with_timeout (this._main_loop);
    }

  private async void test_change_primary_store_setting_async ()
    {
      this._settings = new Settings ("org.freedesktop.folks");
      var key_set = this._settings.set_string ("primary-store", "dummy:dummy-store");
      assert (key_set == true);

      var aggregator = IndividualAggregator.dup ();

      try
        {
          yield aggregator.prepare ();
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }

      /* Initially */
      assert (aggregator.primary_store.id == "dummy-store");

      /* Change the setting value */
      var key_changed = this._settings.set_string ("primary-store",
          "dummy:dummy-store-1");
      assert (key_changed == true);

      /* Checking propagation */
      assert (aggregator.primary_store.id == "dummy-store-1");

      this._main_loop.quit ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new PrimaryStoreChangesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
