using DBus;
using TelepathyGLib;
using TpTest;
using Tpf;
using Folks;
using Gee;

public class PersonaStoreCapabilitiesTests : Folks.TestCase
{
  private DBusDaemon daemon;
  private TpTest.Account account;
  private TpTest.AccountManager account_manager;
  private TpTest.ContactListConnection conn;
  private MainLoop main_loop;
  private string bus_name;
  private string object_path;
  private HashSet<string> group_flags_received;

  public PersonaStoreCapabilitiesTests ()
    {
      base ("PersonaStoreCapabilities");

      this.add_test ("persona store capabilities",
          this.test_persona_store_capabilities);
    }

  public override void set_up ()
    {
      this.group_flags_received = new HashSet<string> (str_hash, str_equal);

      this.main_loop = new GLib.MainLoop (null, false);

      try
        {
          this.daemon = DBusDaemon.dup ();
        }
      catch (GLib.Error e)
        {
          error ("Couldn't get D-Bus daemon: %s", e.message);
        }

      /* Set up a contact list connection */
      this.conn = new TpTest.ContactListConnection ("me@example.com",
          "protocol", 0, 0);

      try
        {
          this.conn.register ("cm", out this.bus_name, out this.object_path);
        }
      catch (GLib.Error e)
        {
          error ("Failed to register connection %p.", this.conn);
        }

      var handle_repo = this.conn.get_handles (HandleType.CONTACT);
      Handle self_handle = 0;
      try
        {
          self_handle = TelepathyGLib.handle_ensure (handle_repo,
              "me@example.com", null);
        }
      catch (GLib.Error e)
        {
          error ("Couldn't ensure self handle '%s': %s", "me@example.com",
              e.message);
        }

      this.conn.set_self_handle (self_handle);
      this.conn.change_status (ConnectionStatus.CONNECTED,
          ConnectionStatusReason.REQUESTED);

      /* Create an account */
      this.account = new TpTest.Account (this.object_path);
      this.daemon.register_object (
          TelepathyGLib.ACCOUNT_OBJECT_PATH_BASE + "cm/protocol/account",
          this.account);

      /* Create an account manager */
      try
        {
          this.daemon.request_name (TelepathyGLib.ACCOUNT_MANAGER_BUS_NAME,
              false);
        }
      catch (GLib.Error e)
        {
          error ("Couldn't request account manager bus name '%s': %s",
              TelepathyGLib.ACCOUNT_MANAGER_BUS_NAME, e.message);
        }

      this.account_manager = new TpTest.AccountManager ();
      this.daemon.register_object (TelepathyGLib.ACCOUNT_MANAGER_OBJECT_PATH,
          this.account_manager);
    }

  public override void tear_down ()
    {
      this.conn.change_status (ConnectionStatus.DISCONNECTED,
          ConnectionStatusReason.REQUESTED);

      this.daemon.unregister_object (this.account_manager);
      this.account_manager = null;

      try
        {
          this.daemon.release_name (TelepathyGLib.ACCOUNT_MANAGER_BUS_NAME);
        }
      catch (GLib.Error e)
        {
          error ("Couldn't release account manager bus name '%s': %s",
              TelepathyGLib.ACCOUNT_MANAGER_BUS_NAME, e.message);
        }

      this.daemon.unregister_object (this.account);
      this.account = null;

      this.conn = null;
      this.daemon = null;
      this.bus_name = null;
      this.object_path = null;

      Timeout.add_seconds (5, () =>
        {
          this.main_loop.quit ();
          this.main_loop = null;
          return false;
        });

      /* Run the main loop to process the carnage and destruction */
      this.main_loop.run ();
    }

  public void test_persona_store_capabilities ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Ignore the error caused by not running the logger */
      Test.log_set_fatal_handler ((d, l, m) =>
        {
          return !m.has_suffix ("couldn't get list of favourite contacts: " +
              "The name org.freedesktop.Telepathy.Logger was not provided by " +
              "any .service files");
        });

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
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new PersonaStoreCapabilitiesTests ().get_suite ());

  Test.run ();

  return 0;
}
