using DBus;
using TelepathyGLib;
using TpTest;
using Tpf;
using Folks;
using Gee;

public class ContactRetrievalTests : Folks.TestCase
{
  private DBusDaemon daemon;
  private TpTest.Account account;
  private TpTest.AccountManager account_manager;
  private TpTest.ContactListConnection conn;
  private MainLoop main_loop;
  private string bus_name;
  private string object_path;
  private HashSet<string> default_individuals;
  private string individual_id_prefix = "telepathy:protocol:";

  public ContactRetrievalTests ()
    {
      base ("ContactRetrieval");

      /* Create a set of the individuals we expect to see */
      this.default_individuals = new HashSet<string> (str_hash, str_equal);

      var prefix = this.individual_id_prefix;
      default_individuals.add (prefix + "travis@example.com");
      default_individuals.add (prefix + "olivier@example.com");
      default_individuals.add (prefix + "guillaume@example.com");
      default_individuals.add (prefix + "sjoerd@example.com");
      default_individuals.add (prefix + "christian@example.com");
      default_individuals.add (prefix + "wim@example.com");
      default_individuals.add (prefix + "helen@example.com");
      default_individuals.add (prefix + "geraldine@example.com");

      this.add_test ("aggregator", this.test_aggregator);
      this.add_test ("aggregator:add", this.test_aggregator_add);
    }

  public override void set_up ()
    {
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

  public void test_aggregator ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Ignore the error caused by not running the logger */
      Test.log_set_fatal_handler ((d, l, m) =>
        {
          return !m.has_suffix ("couldn't get list of favourite contacts: " +
              "The name org.freedesktop.Telepathy.Logger was not provided by " +
              "any .service files");
        });

      /* work on a copy so we can mangle it */
      HashSet<string> expected_individuals = new HashSet<string> ();
      foreach (var id in this.default_individuals)
        expected_individuals.add (id);

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          foreach (Individual i in added)
            expected_individuals.remove (i.id);

          assert (removed == null);
        });

      /* Kill the main loop after a few seconds. If there are still individuals
       * in the set of expected individuals, the aggregator has either failed or
       * been too slow (which we can consider to be failure). */
      Timeout.add_seconds (3, () =>
        {
          main_loop.quit ();
          return false;
        });

      Idle.add (() =>
        {
          aggregator.prepare.begin ((s,r) =>
            {
              try
                {
                  aggregator.prepare.end (r);
                }
              catch (GLib.Error e1)
                {
                  GLib.critical ("failed to prepare aggregator: %s",
                    e1.message);
                  assert_not_reached ();
                }
            });

          return false;
        });

      main_loop.run ();

      /* We should have enumerated exactly the individuals in the set */
      assert (expected_individuals.size == 0);

      /* necessary to reset the aggregator for the next test */
      aggregator = null;
    }

  public void test_aggregator_add ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Ignore the error caused by not running the logger */
      Test.log_set_fatal_handler ((d, l, m) =>
        {
          return !m.has_suffix ("couldn't get list of favourite contacts: " +
              "The name org.freedesktop.Telepathy.Logger was not provided by " +
              "any .service files");
        });

      HashSet<string> added_individuals = new HashSet<string> ();
      added_individuals.add ("master.shake@example.com");
      added_individuals.add ("2wycked@example.com");
      added_individuals.add ("carl-brutananadilewski@example.com");

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();

      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          /* implicitly ignore the default Individuals, since that's covered in
           * other test(s) */
          foreach (Individual i in added)
            {
              /* If the Individual contains a Persona with an ID we provided,
               * mark it as recieved.
               * This intentionally avoids assuming that the Individual's ID is
               * necessarily related to the ID of any of its Persona(s) */
              foreach (Folks.Persona p in i.personas)
                {
                  if (p is Tpf.Persona)
                    if (added_individuals.remove (((Tpf.Persona) p).display_id))
                      break;
                }
            }

          assert (removed == null);
        });

      /* Kill the main loop after a few seconds. If there are still individuals
       * in the set of expected individuals, the aggregator has either failed or
       * been too slow (which we can consider to be failure). */
      Timeout.add_seconds (3, () =>
        {
          main_loop.quit ();
          return false;
        });

      Idle.add (() =>
        {
          aggregator.prepare.begin ((s,r) =>
            {
              try
                {
                  aggregator.prepare.end (r);
                }
              catch (GLib.Error e1)
                {
                  GLib.critical ("failed to prepare aggregator: %s",
                    e1.message);
                  assert_not_reached ();
                }

              /* at this point, all the backends are prepared */

              /* FIXME: the fact that this is so awkward means this is a point
               * of improvement in the API */

              var adding_done = false;

              /* once we see a valid Tpf.PersonaStore, add our new personas */
              var backend_store = BackendStore.dup ();
              foreach (var backend in backend_store.enabled_backends)
                {
                  /* PersonaStores can be added after the backend is prepared */
                  backend.persona_store_added.connect ((store) =>
                    {
                      if (store is Tpf.PersonaStore && !adding_done)
                        {
                          this.add_personas.begin ((Tpf.PersonaStore) store,
                            added_individuals);
                          adding_done = true;
                        }
                    });

                  foreach (var store in
                      backend.persona_stores.get_values ())
                    {
                      if (store is Tpf.PersonaStore && !adding_done)
                        {
                          this.add_personas.begin ((Tpf.PersonaStore) store,
                            added_individuals);
                          adding_done = true;
                        }
                    }
                }
            });

          return false;
        });

      main_loop.run ();

      /* We should have received (and removed) the individuals in the set */
      assert (added_individuals.size == 0);

      /* necessary to reset the aggregator for the next test */
      aggregator = null;
    }

  private async void add_personas (Tpf.PersonaStore store,
      HashSet<string>? ids_add)
    {
      try
        {
          yield store.prepare ();

          /* track which IDs have been successfully added, since
           * add_persona_from_details can temporarily fail with
           * PersonaStoreError.STORE_OFFLINE (in which case, we just need to try
           * again later) */
          var ids_remaining = new HashSet<string> (str_hash, str_equal);
          foreach (var contact_id in ids_add)
            ids_remaining.add (contact_id);

          Idle.add (() =>
            {
              var try_again = false;

              foreach (var id in ids_remaining)
                {
                  var details = new HashTable<string, GLib.Value?> (str_hash,
                      str_equal);
                  details.insert ("contact", id);

                  /* we can end up adding the same ID twice, since this async
                   * function can be called a second time before the first
                   * completes. But add_persona_from_details() is idempotent, so
                   * this is acceptable (and not worth the extra code) */
                  store.add_persona_from_details.begin (details, (s2, res) =>
                      {
                        try
                          {
                            store.add_persona_from_details.end (res);

                            var id_added_value = details.lookup ("contact");
                            var id_added = id_added_value.get_string ();
                            if (id_added != null)
                              ids_remaining.remove (id_added);
                          }
                        catch (GLib.Error e1)
                          {
                            /* STORE_OFFLINE is acceptable -- see above */
                            if (!(e1 is PersonaStoreError.STORE_OFFLINE))
                              {
                                GLib.critical ("failed to add persona: %s",
                                  e1.message);
                                assert_not_reached ();
                              }
                          }
                      });

                  try_again = (ids_remaining.size > 0);
                  if (try_again)
                    break;
                }

              return try_again;
            });
        }
      catch (GLib.Error e2)
        {
          warning ("Error preparing PersonaStore '%s': %s", store.id,
              e2.message);
          assert_not_reached ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new ContactRetrievalTests ().get_suite ());

  Test.run ();

  return 0;
}
