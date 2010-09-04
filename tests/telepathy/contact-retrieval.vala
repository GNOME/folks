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
      this.add_test ("individual properties",
          this.test_individual_properties);
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
          "protocol");

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
      aggregator.prepare ();

      /* Kill the main loop after a few seconds. If there are still individuals
       * in the set of expected individuals, the aggregator has either failed
       * or been too slow (which we can consider to be failure). */
      Timeout.add_seconds (3, () =>
        {
          main_loop.quit ();
          return false;
        });

      main_loop.run ();

      /* We should have enumerated exactly the individuals in the set */
      assert (expected_individuals.size == 0);
    }

  public void test_individual_properties ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Ignore the error caused by not running the logger */
      Test.log_set_fatal_handler ((d, l, m) =>
        {
          return !m.has_suffix ("couldn't get list of favourite contacts: " +
              "The name org.freedesktop.Telepathy.Logger was not provided by " +
              "any .service files");
        });

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          foreach (Individual i in added)
            {
              /* We only check one */
              if (i.id != "telepathy:protocol:olivier@example.com")
                {
                  continue;
                }

              /* Check properties */
              assert (i.alias == "Olivier");
              assert (i.presence_message == "");
              assert (i.presence_type == PresenceType.AWAY);
              assert (i.is_online () == true);

              /* Check groups */
              assert (i.groups.size () == 2);
              assert (i.groups.lookup ("Montreal") == true);
              assert (i.groups.lookup ("Francophones") == true);
            }

          assert (removed == null);
        });
      aggregator.prepare ();

      /* Kill the main loop after a few seconds. If there are still individuals
       * in the set of expected individuals, the aggregator has either failed
       * or been too slow (which we can consider to be failure). */
      Timeout.add_seconds (3, () =>
        {
          main_loop.quit ();
          return false;
        });

      main_loop.run ();
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
