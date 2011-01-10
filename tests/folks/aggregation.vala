using Gee;
using Folks;
using TpTest;

public class AggregationTests : Folks.TestCase
{
  private KfTest.Backend _kf_backend;
  private TpTest.Backend _tp_backend;
  private HashSet<string> _default_individuals;
  private string _individual_id_prefix = "telepathy:protocol:";

  public AggregationTests ()
    {
      base ("Aggregation");

      this._kf_backend = new KfTest.Backend ();
      this._tp_backend = new TpTest.Backend ();

      /* Create a set of the individuals we expect to see */
      this._default_individuals = new HashSet<string> (str_hash, str_equal);

      this._default_individuals.add ("travis@example.com");
      this._default_individuals.add ("olivier@example.com");
      this._default_individuals.add ("guillaume@example.com");
      this._default_individuals.add ("sjoerd@example.com");
      this._default_individuals.add ("christian@example.com");
      this._default_individuals.add ("wim@example.com");
      this._default_individuals.add ("helen@example.com");
      this._default_individuals.add ("geraldine@example.com");

      /* Set up the tests */
      this.add_test ("IID", this.test_iid);
      this.add_test ("linkable properties:same store",
          this.test_linkable_properties_same_store);
      this.add_test ("linkable properties:different stores",
          this.test_linkable_properties_different_stores);
      this.add_test ("user", this.test_user);
      this.add_test ("untrusted store", this.test_untrusted_store);
    }

  public override void set_up ()
    {
      this._tp_backend.set_up ();
    }

  public override void tear_down ()
    {
      this._tp_backend.tear_down ();
    }

  /* Test that personas are aggregated if their IIDs match (e.g. with the
   * Telepathy backend, this would happen if you added the same contact in two
   * different accounts on the same protocol).
   * We simulate this by having two different accounts connected on the same
   * protocol, both with identical contact lists. We then assert that all
   * individuals have two personas, and that they're on the list of expected
   * individuals. */
  public void test_iid ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Ignore the error caused by not running the logger */
      Test.log_set_fatal_handler ((d, l, m) =>
        {
          return !m.has_suffix ("The name org.freedesktop.Telepathy.Logger " +
              "was not provided by any .service files");
        });

      this._kf_backend.set_up ("");

      void* account1_handle = this._tp_backend.add_account ("protocol",
          "me@example.com", "cm", "account");
      void* account2_handle = this._tp_backend.add_account ("protocol",
          "me2@example.com", "cm", "account2");

      /* Work on a copy of the set of individuals so we can mangle it */
      HashSet<string> expected_individuals = new HashSet<string> ();
      foreach (var id in this._default_individuals)
        {
          expected_individuals.add (this._individual_id_prefix + id);
        }

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          /* If an individual is removed, add them back to the set of expected
           * individuals (if they were originally on it) */
          foreach (Individual i in removed)
            {
              if (!i.is_user &&
                  i.personas.length () == 2 &&
                  this._default_individuals.contains (i.id))
                {
                  expected_individuals.add (i.id);
                }
            }

          /* If an individual is added (and has been fully linked), remove them
           * from the set of expected individuals. */
          foreach (Individual i in added)
            {
              unowned GLib.List<Persona> personas = i.personas;

              /* We're not testing the user here */
              if (!i.is_user && personas.length () == 2)
                {
                  assert (expected_individuals.remove (i.id));
                  assert (personas.data.iid == personas.next.data.iid);
                }
            }
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
                  GLib.critical ("Failed to prepare aggregator: %s",
                    e1.message);
                  assert_not_reached ();
                }
            });

          return false;
        });

      main_loop.run ();

      /* We should have enumerated exactly the individuals in the set */
      assert (expected_individuals.size == 0);

      /* Clean up for the next test */
      this._tp_backend.remove_account (account2_handle);
      this._tp_backend.remove_account (account1_handle);
      this._kf_backend.tear_down ();
      aggregator = null;
    }

  /* Test that personas from a single persona store are aggregated if their IIDs
   * match linkable properties of other personas (i.e. the typical case of
   * manually linked personas). We do this by specifying a key file which links
   * together the personas in the test Telepathy account into two groups. We
   * then assert that we end up with exactly two individuals (ignoring the user)
   * which contain the correct personas. */
  public void test_linkable_properties_same_store ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Ignore the error caused by not running the logger */
      Test.log_set_fatal_handler ((d, l, m) =>
        {
          return !m.has_suffix ("The name org.freedesktop.Telepathy.Logger " +
              "was not provided by any .service files");
        });

      this._kf_backend.set_up ("[0]\n" +
          "protocol=travis@example.com;olivier@example.com;" +
              "guillaume@example.com;sjoerd@example.com\n" +
          "[1]\n" +
          "protocol=christian@example.com;wim@example.com;" +
              "helen@example.com;geraldine@example.com");

      void* account_handle = this._tp_backend.add_account ("protocol",
          "me@example.com", "cm", "account");

      /* We expect two non-user individuals (each containing four Telepathy
       * personas and one key-file persona) */
      weak Individual individual1 = null;
      weak Individual individual2 = null;

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          foreach (Individual i in removed)
            {
              if (!i.is_user && i.personas.length () == 5)
                {
                  if (i == individual1)
                    {
                      individual1 = null;
                    }
                  else if (i == individual2)
                    {
                      individual2 = null;
                    }
                  else
                    {
                      GLib.critical ("Unknown 5-persona individual: %s", i.id);
                      assert_not_reached ();
                    }
                }
            }

          foreach (Individual i in added)
            {
              if (!i.is_user && i.personas.length () == 5)
                {
                  if (individual1 == null)
                    {
                     individual1 = i;
                    }
                  else if (individual2 == null)
                    {
                      individual2 = i;
                    }
                  else
                    {
                      GLib.critical ("Unknown 5-persona individual: %s", i.id);
                      assert_not_reached ();
                    }
                }
            }
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
                  GLib.critical ("Failed to prepare aggregator: %s",
                    e1.message);
                  assert_not_reached ();
                }
            });

          return false;
        });

      main_loop.run ();

      /* Verify the two individuals we should have */
      assert (individual1 != null);
      assert (individual2 != null);

      var individual1_expected = new HashSet<string> ();
      individual1_expected.add ("0");
      individual1_expected.add ("travis@example.com");
      individual1_expected.add ("olivier@example.com");
      individual1_expected.add ("guillaume@example.com");
      individual1_expected.add ("sjoerd@example.com");

      var individual2_expected = new HashSet<string> ();
      individual2_expected.add ("1");
      individual2_expected.add ("christian@example.com");
      individual2_expected.add ("wim@example.com");
      individual2_expected.add ("helen@example.com");
      individual2_expected.add ("geraldine@example.com");

      HashSet<string> set_in_use = null;
      foreach (var p in individual1.personas)
        {
          /* Work out which of the two individuals this is */
          if (set_in_use == null &&
              individual1_expected.contains (p.display_id))
            {
              set_in_use = individual1_expected;
            }
          else if (set_in_use == null)
            {
              set_in_use = individual2_expected;
            }

          assert (set_in_use.remove (p.display_id));
        }

      assert (set_in_use.size == 0);

      if (set_in_use == individual1_expected)
        {
          set_in_use = individual2_expected;
        }
      else
        {
          set_in_use = individual1_expected;
        }

      foreach (var p in individual2.personas)
        {
          assert (set_in_use.remove (p.display_id));
        }

      assert (set_in_use.size == 0);

      /* Clean up for the next test */
      this._tp_backend.remove_account (account_handle);
      this._kf_backend.tear_down ();
      aggregator = null;
    }

  /* Test that personas from different persona stores are aggregated if their
   * IIDs match linkable properties of other personas (i.e. another typical case
   * of manually linked personas). We do this by specifying a key file which
   * links together the personas in two instances of the test Telepathy account,
   * set up with different protocols, into two groups. We then assert that we
   * end up with exactly two individuals (ignoring the user) which contain the
   * correct personas. */
  public void test_linkable_properties_different_stores ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Ignore the error caused by not running the logger */
      Test.log_set_fatal_handler ((d, l, m) =>
        {
          return !m.has_suffix ("The name org.freedesktop.Telepathy.Logger " +
              "was not provided by any .service files");
        });

      this._kf_backend.set_up ("[0]\n" +
          "protocol=travis@example.com;olivier@example.com;" +
              "guillaume@example.com;sjoerd@example.com\n" +
          "protocol2=christian@example.com;wim@example.com;" +
              "helen@example.com;geraldine@example.com\n" +
          "[1]\n" +
          "protocol=christian@example.com;wim@example.com;" +
              "helen@example.com;geraldine@example.com\n" +
          "protocol2=travis@example.com;olivier@example.com;" +
              "guillaume@example.com;sjoerd@example.com");

      void* account1_handle = this._tp_backend.add_account ("protocol",
          "me@example.com", "cm", "account");
      void* account2_handle = this._tp_backend.add_account ("protocol2",
          "me@example.com", "cm", "account2");

      /* We expect two non-user individuals (each containing four Telepathy
       * personas and one key-file persona) */
      weak Individual individual1 = null;
      weak Individual individual2 = null;

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          foreach (Individual i in removed)
            {
              if (!i.is_user && i.personas.length () == 9)
                {
                  if (i == individual1)
                    {
                      individual1 = null;
                    }
                  else if (i == individual2)
                    {
                      individual2 = null;
                    }
                  else
                    {
                      GLib.critical ("Unknown 9-persona individual: %s", i.id);
                      assert_not_reached ();
                    }
                }
            }

          foreach (Individual i in added)
            {
              if (!i.is_user && i.personas.length () == 9)
                {
                  if (individual1 == null)
                    {
                     individual1 = i;
                    }
                  else if (individual2 == null)
                    {
                      individual2 = i;
                    }
                  else
                    {
                      GLib.critical ("Unknown 9-persona individual: %s", i.id);
                      assert_not_reached ();
                    }
                }
            }
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
                  GLib.critical ("Failed to prepare aggregator: %s",
                    e1.message);
                  assert_not_reached ();
                }
            });

          return false;
        });

      main_loop.run ();

      /* Verify the two individuals we should have */
      assert (individual1 != null);
      assert (individual2 != null);

      /* Work on a copy of the set of individuals so we can mangle it.
       * We expect the two individuals to each have exactly one of the default
       * personas, half of which should come from one persona store, and half
       * from a different persona store. */
      var expected_personas1 = new HashSet<string> ();
      var expected_personas2 = new HashSet<string> ();
      foreach (var id in this._default_individuals)
        {
          expected_personas1.add (id);
          expected_personas2.add (id);
        }

      foreach (var p in individual1.personas)
        {
          assert (expected_personas1.remove (p.display_id) ||
              p.display_id == "0" || p.display_id == "1");
        }

      assert (expected_personas1.size == 0);

      foreach (var p in individual2.personas)
        {
          assert (expected_personas2.remove (p.display_id) ||
              p.display_id == "0" || p.display_id == "1");
        }

      assert (expected_personas2.size == 0);

      /* Clean up for the next test */
      this._tp_backend.remove_account (account2_handle);
      this._tp_backend.remove_account (account1_handle);
      this._kf_backend.tear_down ();
      aggregator = null;
    }

  /* Test that the personas which have the is-user property marked as true
   * are linked together, even if they're from different persona stores. */
  public void test_user ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Ignore the error caused by not running the logger */
      Test.log_set_fatal_handler ((d, l, m) =>
        {
          return !m.has_suffix ("The name org.freedesktop.Telepathy.Logger " +
              "was not provided by any .service files");
        });

      this._kf_backend.set_up ("");

      void* account1_handle = this._tp_backend.add_account ("protocol",
          "me@example.com", "cm", "account");
      void* account2_handle = this._tp_backend.add_account ("protocol",
          "me2@example.com", "cm", "account2");

      Individual user_individual = null;

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          /* Keep track of the user individual */
          foreach (Individual i in removed)
            {
              if (i.is_user)
                {
                  assert (user_individual == i);
                  user_individual = null;
                }
            }

          foreach (Individual i in added)
            {
              if (i.is_user)
                {
                  assert (user_individual == null);
                  user_individual = i;
                }
            }
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
                  GLib.critical ("Failed to prepare aggregator: %s",
                    e1.message);
                  assert_not_reached ();
                }
            });

          return false;
        });

      main_loop.run ();

      /* The user exported by the aggregator should be the same as the one
       * we've kept track of */
      assert (aggregator.user == user_individual);

      /* The user individual should comprise personas from the two accounts */
      assert (user_individual.personas.length () == 2);
      assert ((user_individual.personas.data.display_id == "me@example.com" &&
          user_individual.personas.next.data.display_id == "me2@example.com") ||
          (user_individual.personas.data.display_id == "me2@example.com" &&
          user_individual.personas.next.data.display_id == "me@example.com"));

      /* Clean up for the next test */
      this._tp_backend.remove_account (account2_handle);
      this._tp_backend.remove_account (account1_handle);
      this._kf_backend.tear_down ();
      aggregator = null;
    }

  /* Test that the personas from an untrusted store (e.g. one which represents
   * an IRC connection in Telepathy) are not linked, even if they would
   * otherwise be linked due to their IIDs. */
  public void test_untrusted_store ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Ignore the error caused by not running the logger */
      Test.log_set_fatal_handler ((d, l, m) =>
        {
          return !m.has_suffix ("The name org.freedesktop.Telepathy.Logger " +
              "was not provided by any .service files");
        });

      this._kf_backend.set_up ("");

      void* account1_handle = this._tp_backend.add_account ("irc",
          "me@example.com", "cm", "account");
      void* account2_handle = this._tp_backend.add_account ("irc",
          "me2@example.com", "cm", "account2");

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          /* Assert that no aggregation occurs at all (except with the
           * personas for the user). */
          foreach (Individual i in removed)
            {
              assert (i.is_user || i.personas.length () == 1);
            }

          foreach (Individual i in added)
            {
              assert (i.is_user || i.personas.length () == 1);
            }
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
                  GLib.critical ("Failed to prepare aggregator: %s",
                    e1.message);
                  assert_not_reached ();
                }
            });

          return false;
        });

      main_loop.run ();

      /* Clean up for the next test */
      this._tp_backend.remove_account (account2_handle);
      this._tp_backend.remove_account (account1_handle);
      this._kf_backend.tear_down ();
      aggregator = null;
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new AggregationTests ().get_suite ());

  Test.run ();

  return 0;
}
