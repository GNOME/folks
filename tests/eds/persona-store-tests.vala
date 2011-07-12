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

using EdsTest;
using Folks;
using Gee;

public class PersonaStoreTests : Folks.TestCase
{
  private EdsTest.Backend eds_backend;
  private HashSet<string> group_flags_received;

  public PersonaStoreTests ()
    {
      base ("PersonaStoreTests");
      this.eds_backend = new EdsTest.Backend ();
      this.add_test ("persona store tests", this.test_persona_store);
    }

  public override void set_up ()
    {
      this.group_flags_received = new HashSet<string> (str_hash, str_equal);
      this.eds_backend.set_up ();
    }

  public override void tear_down ()
    {
    }

  public void test_persona_store ()
    {
      Gee.HashMap<string, Value?> c1 = new Gee.HashMap<string, Value?> ();
      Gee.HashMap<string, Value?> c2 = new Gee.HashMap<string, Value?> ();
      var main_loop = new GLib.MainLoop (null, false);
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
                      this.set_up_persona_store (ps);
                    });

                foreach (var store in b.persona_stores.values)
                  {
                    this.set_up_persona_store (store);
                  }

              }
          });

      backend_store.load_backends ();

      Timeout.add_seconds (3, () =>
        {
          main_loop.quit ();
          return false;
        });

      main_loop.run ();

      this.eds_backend.tear_down ();
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

              if (store.can_alias_personas != MaybeBool.UNSET)
                can_alias_personas_cb (store, null);
              else
                store.notify["can-alias-personas"].connect (
                    this.can_alias_personas_cb);

              if (store.can_group_personas != MaybeBool.UNSET)
                can_group_personas_cb (store, null);
              else
                store.notify["can-group-personas"].connect (
                    this.can_group_personas_cb);
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
      assert (s is Edsf.PersonaStore);
      var store = (Edsf.PersonaStore) s;

      if (store.can_add_personas != MaybeBool.UNSET)
        {
          assert (store.can_add_personas == MaybeBool.TRUE);

          store.notify["can-add-personas"].disconnect (
              this.can_add_personas_cb);
        }
    }

  private void can_remove_personas_cb (GLib.Object s, ParamSpec? p)
    {
      assert (s is Edsf.PersonaStore);
      var store = (Edsf.PersonaStore) s;

      if (store.can_remove_personas != MaybeBool.UNSET)
        {
          assert (store.can_remove_personas == MaybeBool.TRUE);

          store.notify["can-remove-personas"].disconnect (
              this.can_remove_personas_cb);
        }
    }

  private void can_alias_personas_cb (GLib.Object s, ParamSpec? p)
    {
      assert (s is Edsf.PersonaStore);
      var store = (Edsf.PersonaStore) s;

      if (store.can_alias_personas != MaybeBool.UNSET)
        {
          assert (store.can_alias_personas == MaybeBool.FALSE);

          store.notify["can-alias-personas"].disconnect (
              this.can_alias_personas_cb);
        }
    }

  private void can_group_personas_cb (GLib.Object s, ParamSpec? p)
    {
      assert (s is Edsf.PersonaStore);
      var store = (Edsf.PersonaStore) s;

      if (store.can_group_personas != MaybeBool.UNSET)
        {
          assert (store.can_group_personas == MaybeBool.FALSE);

          store.notify["can-group-personas"].disconnect (
              this.can_group_personas_cb);
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new PersonaStoreTests ().get_suite ());

  Test.run ();

  return 0;
}
