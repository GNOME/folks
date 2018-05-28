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
 * Authors: Travis Reitter <travis.reitter@collabora.co.uk>
 */

using DBus;
using TelepathyGLib;
using TpTests;
using Tpf;
using Folks;
using Gee;

public class PersonaStoreCapabilitiesTests : TpfTest.TestCase
{
  private HashSet<string>? _capabilities_received = null;

  public PersonaStoreCapabilitiesTests ()
    {
      base ("PersonaStoreCapabilities");

      this.add_test ("persona store capabilities",
          this.test_persona_store_capabilities);
    }

  public override void set_up ()
    {
      base.set_up ();

      this._capabilities_received = new HashSet<string> ();
    }

  public override void tear_down ()
    {
      this._capabilities_received = null;

      base.tear_down ();
    }

  public void test_persona_store_capabilities ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      var backend_store = BackendStore.dup ();
      backend_store.backend_available.connect ((b) =>
          {
            if (b.name == "telepathy")
              {
                b.persona_store_added.connect ((ps) =>
                    {
                      this.set_up_persona_store (ps);
                    });

                foreach (var store in b.persona_stores.values)
                  {
                    this.set_up_persona_store (store);
                  }

              }

          });

      backend_store.load_backends.begin ();

      TestUtils.loop_run_with_timeout (main_loop);

      assert (this._capabilities_received.contains ("can-add-personas"));
      assert (this._capabilities_received.contains ("can-remove-personas"));
      assert (!this._capabilities_received.contains ("can-alias-personas"));
      assert (!this._capabilities_received.contains ("can-group-personas"));
    }

  private void set_up_persona_store (Folks.PersonaStore store)
    {
      store.prepare.begin ((obj, result) =>
        {
          try
            {
              store.prepare.end (result);

              if (store.can_add_personas != MaybeBool.UNSET)
                can_add_personas_cb (store, null);
              else
                store.notify["can-add-personas"].connect (
                    this.can_add_personas_cb);

              if (store.can_remove_personas != MaybeBool.UNSET)
                can_remove_personas_cb (store, null);
              else
                store.notify["can-remove-personas"].connect (
                    this.can_remove_personas_cb);

              if ("alias" in store.always_writeable_properties)
                check_can_alias_personas (store, null);

              if ("groups" in store.always_writeable_properties)
                check_can_group_personas_cb (store, null);
            }
          catch (GLib.Error e)
            {
              warning ("Error preparing PersonaStore type: %s, id: %s: " +
                "'%s'", store.type_id, store.id, e.message);
            }
        });
    }

  private void can_add_personas_cb (GLib.Object s, ParamSpec? p)
    {
      assert (s is Tpf.PersonaStore);
      var store = (Tpf.PersonaStore) s;

      if (store.can_add_personas != MaybeBool.UNSET)
        {
          assert (store.can_add_personas == MaybeBool.TRUE);

          this._capabilities_received.add ("can-add-personas");

          store.notify["can-add-personas"].disconnect (
              this.can_add_personas_cb);
        }
    }

  private void can_remove_personas_cb (GLib.Object s, ParamSpec? p)
    {
      assert (s is Tpf.PersonaStore);
      var store = (Tpf.PersonaStore) s;

      if (store.can_remove_personas != MaybeBool.UNSET)
        {
          assert (store.can_remove_personas == MaybeBool.TRUE);

          this._capabilities_received.add ("can-remove-personas");

          store.notify["can-remove-personas"].disconnect (
              this.can_remove_personas_cb);
        }
    }

  private void check_can_alias_personas (GLib.Object s, ParamSpec? p)
    {
      assert (s is Tpf.PersonaStore);
      var store = (Tpf.PersonaStore) s;

      if ("alias" in store.always_writeable_properties)
        this._capabilities_received.add ("can-alias-personas");
    }

  private void check_can_group_personas_cb (GLib.Object s, ParamSpec? p)
    {
      assert (s is Tpf.PersonaStore);
      var store = (Tpf.PersonaStore) s;

      if ("groups" in store.always_writeable_properties)
        this._capabilities_received.add ("can-group-personas");
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new PersonaStoreCapabilitiesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
