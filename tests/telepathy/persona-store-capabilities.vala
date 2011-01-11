using DBus;
using TelepathyGLib;
using TpTest;
using Tpf;
using Folks;
using Gee;

public class PersonaStoreCapabilitiesTests : Folks.TestCase
{
  private TpTest.Backend tp_backend;
  private HashSet<string> group_flags_received;

  public PersonaStoreCapabilitiesTests ()
    {
      base ("PersonaStoreCapabilities");

      this.tp_backend = new TpTest.Backend ();

      this.add_test ("persona store capabilities",
          this.test_persona_store_capabilities);
    }

  public override void set_up ()
    {
      this.group_flags_received = new HashSet<string> (str_hash, str_equal);

      this.tp_backend.set_up ();
    }

  public override void tear_down ()
    {
      this.tp_backend.tear_down ();
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

                foreach (var store in b.persona_stores.get_values ())
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

      assert (this.group_flags_received.contains ("can-add-personas"));
      assert (this.group_flags_received.contains ("can-remove-personas"));
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
      assert (s is Tpf.PersonaStore);
      var store = (Tpf.PersonaStore) s;

      if (store.can_add_personas != MaybeBool.UNSET)
        {
          assert (store.can_add_personas == MaybeBool.TRUE);

          this.group_flags_received.add ("can-add-personas");

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

          this.group_flags_received.add ("can-remove-personas");

          store.notify["can-remove-personas"].disconnect (
              this.can_remove_personas_cb);
        }
    }

  private void can_alias_personas_cb (GLib.Object s, ParamSpec? p)
    {
      assert (s is Tpf.PersonaStore);
      var store = (Tpf.PersonaStore) s;

      if (store.can_alias_personas != MaybeBool.UNSET)
        {
          assert (store.can_alias_personas == MaybeBool.TRUE);

          this.group_flags_received.add ("can-alias-personas");

          store.notify["can-alias-personas"].disconnect (
              this.can_alias_personas_cb);
        }
    }

  private void can_group_personas_cb (GLib.Object s, ParamSpec? p)
    {
      assert (s is Tpf.PersonaStore);
      var store = (Tpf.PersonaStore) s;

      if (store.can_group_personas != MaybeBool.UNSET)
        {
          assert (store.can_group_personas == MaybeBool.TRUE);

          this.group_flags_received.add ("can-group-personas");

          store.notify["can-group-personas"].disconnect (
              this.can_group_personas_cb);
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new PersonaStoreCapabilitiesTests ().get_suite ());

  Test.run ();

  return 0;
}
