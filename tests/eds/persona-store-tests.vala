/*
 * Copyright (C) 2011, 2015 Collabora Ltd.
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
 *          Philip Withnall <philip.withnall@collabora.co.uk>
 *
 */

using EdsTest;
using Folks;
using Gee;

public class PersonaStoreTests : EdsTest.TestCase
{
  private HashSet<string>? _capabilities_received = null;
  private MainLoop? _main_loop = null;
  private uint _callbacks_received = 0;

  public PersonaStoreTests ()
    {
      base ("PersonaStoreTests");
      this.add_test ("persona store tests", this.test_persona_store);
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

  public void test_persona_store ()
    {
      Gee.HashMap<string, Value?> c1 = new Gee.HashMap<string, Value?> ();
      Gee.HashMap<string, Value?> c2 = new Gee.HashMap<string, Value?> ();
      this._main_loop = new GLib.MainLoop (null, false);
      Value? v;

      this.eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      c1.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("bernie@example.org");
      c1.set (Edsf.Persona.email_fields[0], (owned) v);
      this.eds_backend.add_contact (c1);

      v = Value (typeof (string));
      v.set_string ("richard m. stallman");
      c2.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("rms@example.org");
      c2.set (Edsf.Persona.email_fields[0], (owned) v);
      this.eds_backend.add_contact (c2);

      this._callbacks_received = 0;

      var backend_store = BackendStore.dup ();
      backend_store.prepare.begin ((o, r) =>
        {
          backend_store.prepare.end (r);
        });
      backend_store.backend_available.connect ((b) =>
          {
            if (b.name == "eds")
              {
                b.persona_store_added.connect ((ps) =>
                    {
                      this._set_up_persona_store (ps);
                    });

                foreach (var store in b.persona_stores.values)
                  {
                    this._set_up_persona_store (store);
                  }

              }
          });

      backend_store.load_backends.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._capabilities_received.contains ("can-add-personas"));
      assert (this._capabilities_received.contains ("can-remove-personas"));
      assert (!this._capabilities_received.contains ("can-alias-personas"));
      assert (this._capabilities_received.contains ("can-group-personas"));

      this.eds_backend.tear_down ();
    }

  private void _set_up_persona_store (Folks.PersonaStore store)
    {
      store.prepare.begin ((obj, result) =>
        {
          try
            {
              store.prepare.end (result);

              if (store.can_add_personas != MaybeBool.UNSET)
                this._can_add_personas_cb (store, null);
              else
                store.notify["can-add-personas"].connect (
                    this._can_add_personas_cb);

              if (store.can_remove_personas != MaybeBool.UNSET)
                _can_remove_personas_cb (store, null);
              else
                store.notify["can-remove-personas"].connect (
                    this._can_remove_personas_cb);

              this._check_can_alias_personas (store, null);
              this._check_can_group_personas (store, null);

              if (this._callbacks_received == 4)
                this._main_loop.quit ();
            }
          catch (GLib.Error e)
            {
              warning ("Error preparing PersonaStore type: %s, id: %s: " +
                "'%s'", store.type_id, store.id, e.message);
            }
        });
    }

  private void _can_add_personas_cb (GLib.Object s, ParamSpec? p)
    {
      assert (s is Edsf.PersonaStore);
      var store = (Edsf.PersonaStore) s;
      this._callbacks_received++;

      if (store.can_add_personas != MaybeBool.UNSET)
        {
          assert (store.can_add_personas == MaybeBool.TRUE);

          this._capabilities_received.add ("can-add-personas");

          store.notify["can-add-personas"].disconnect (
              this._can_add_personas_cb);
        }

      if (this._callbacks_received == 4)
        this._main_loop.quit ();
    }

  private void _can_remove_personas_cb (GLib.Object s, ParamSpec? p)
    {
      assert (s is Edsf.PersonaStore);
      var store = (Edsf.PersonaStore) s;
      this._callbacks_received++;

      if (store.can_remove_personas != MaybeBool.UNSET)
        {
          assert (store.can_remove_personas == MaybeBool.TRUE);

          this._capabilities_received.add ("can-remove-personas");

          store.notify["can-remove-personas"].disconnect (
              this._can_remove_personas_cb);
        }

      if (this._callbacks_received == 4)
        this._main_loop.quit ();
    }

  private void _check_can_alias_personas (GLib.Object s, ParamSpec? p)
    {
      assert (s is Edsf.PersonaStore);
      var store = (Edsf.PersonaStore) s;
      this._callbacks_received++;

      if ("alias" in store.always_writeable_properties)
        {
          this._capabilities_received.add ("can-alias-personas");
        }

      if (this._callbacks_received == 4)
        this._main_loop.quit ();
    }

  private void _check_can_group_personas (GLib.Object s, ParamSpec? p)
    {
      assert (s is Edsf.PersonaStore);
      var store = (Edsf.PersonaStore) s;
      this._callbacks_received++;

      if ("groups" in store.always_writeable_properties)
        {
          this._capabilities_received.add ("can-group-personas");
        }

      if (this._callbacks_received == 4)
        this._main_loop.quit ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new PersonaStoreTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
