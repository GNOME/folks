using Gee;
using Folks;
using KfTest;

public class IndividualRetrievalTests : Folks.TestCase
{
  private KfTest.Backend kf_backend;
  private MainLoop main_loop;
  private static const string STORE_FILE_PATH = "folks-key-file-store.ini";

  public IndividualRetrievalTests ()
    {
      base ("IndividualRetrieval");

      this.kf_backend = new KfTest.Backend ();

      this.add_test ("singleton individuals", this.test_singleton_individuals);
      this.add_test ("aliases", this.test_aliases);
    }

  public override void set_up ()
    {
      this.main_loop = new GLib.MainLoop (null, false);

      FileUtils.remove (Path.build_filename (Environment.get_tmp_dir (),
          this.STORE_FILE_PATH, null));

      /* Use a temporary key file for the BackendStore */
      Environment.set_variable ("FOLKS_BACKEND_STORE_KEY_FILE_PATH",
          Path.build_filename (Environment.get_tmp_dir (),
              this.STORE_FILE_PATH, null), true);

      /* Disable the Telepathy backend so it doesn't interfere with the tests */
      BackendStore store = BackendStore.dup ();
      store.prepare.begin ((o, r) =>
        {
          store.prepare.end (r);
          store.disable_backend.begin ("telepathy");
        });
    }

  public override void tear_down ()
    {
      FileUtils.remove (Path.build_filename (Environment.get_tmp_dir (),
          this.STORE_FILE_PATH, null));

      Timeout.add_seconds (5, () =>
        {
          this.main_loop.quit ();
          this.main_loop = null;
          return false;
        });

      /* Run the main loop to process the carnage and destruction */
      this.main_loop.run ();
    }

  public void test_singleton_individuals ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      this.kf_backend.set_up (
          "[0]\n" +
          "msn=foo@hotmail.com\n" +
          "[1]\n" +
          "__alias=Bar McBadgerson\n" +
          "jabber=bar@jabber.org\n");

      /* Ignore the error caused by not running the logger */
      Test.log_set_fatal_handler ((d, l, m) =>
        {
          return !m.has_suffix ("couldn't get list of favourite individuals: " +
              "The name org.freedesktop.Telepathy.Logger was not provided by " +
              "any .service files");
        });

      /* Create a set of the individuals we expect to see */
      HashSet<string> expected_individuals = new HashSet<string> (str_hash,
          str_equal);

      expected_individuals.add ("0");
      expected_individuals.add ("1");

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          foreach (Individual i in added)
            {
              assert (i.personas.length () == 1);
              /* Using the display ID is a little hacky, since we strictly
               * shouldn't assume anything about…but for the key-file backend,
               * we know it's equal to the group name. */
              expected_individuals.remove (i.personas.data.display_id);
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

      /* We should have enumerated exactly the individuals in the set */
      assert (expected_individuals.size == 0);

      this.kf_backend.tear_down ();
    }

  public void test_aliases ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      this.kf_backend.set_up (
          "[0]\n" +
          "__alias=Brian Briansson\n" +
          "msn=foo@hotmail.com\n");

      /* Ignore the error caused by not running the logger */
      Test.log_set_fatal_handler ((d, l, m) =>
        {
          return !m.has_suffix ("couldn't get list of favourite individuals: " +
              "The name org.freedesktop.Telepathy.Logger was not provided by " +
              "any .service files");
        });

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      uint individuals_changed_count = 0;
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          individuals_changed_count++;

          assert (added.length () == 1);
          assert (removed == null);

          /* Check properties */
          assert (added.data.alias == "Brian Briansson");
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

      /* We should have enumerated exactly one individual */
      assert (individuals_changed_count == 1);

      this.kf_backend.tear_down ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new IndividualRetrievalTests ().get_suite ());

  Test.run ();

  return 0;
}
