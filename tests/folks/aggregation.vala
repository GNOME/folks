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

using Gee;
using Folks;
using TpTests;

public class AggregationTests : TpfTest.MixedTestCase
{
  private HashSet<string> _default_personas;

  private static string iid_prefix =
      "telepathy:/org/freedesktop/Telepathy/Account/cm/protocol/account:";
  private string olivier_sha1 = Checksum.compute_for_string (ChecksumType.SHA1,
      iid_prefix + "olivier@example.com");

  public AggregationTests ()
    {
      base ("Aggregation");

      /* Create a set of the individuals we expect to see */
      this._default_personas = new HashSet<string> ();

      this._default_personas.add ("travis@example.com");
      this._default_personas.add ("olivier@example.com");
      this._default_personas.add ("guillaume@example.com");
      this._default_personas.add ("sjoerd@example.com");
      this._default_personas.add ("christian@example.com");
      this._default_personas.add ("wim@example.com");
      this._default_personas.add ("helen@example.com");
      this._default_personas.add ("geraldine@example.com");

      /* Set up the tests */
      this.add_test ("IID", this.test_iid);
      this.add_test ("linkable properties:same store",
          this.test_linkable_properties_same_store);
      this.add_test ("linkable properties:different stores",
          this.test_linkable_properties_different_stores);
      this.add_test ("user", this.test_user);
      this.add_test ("untrusted store", this.test_untrusted_store);
      this.add_test ("refcounting", this.test_linked_individual_refcounting);
      this.add_test ("ensure individual property writeable:trivial",
          this.test_ensure_individual_property_writeable_trivial);
      this.add_test ("ensure individual property writeable:add persona",
          this.test_ensure_individual_property_writeable_add_persona);
      this.add_test ("ensure individual property writeable:failure",
          this.test_ensure_individual_property_writeable_failure);
    }

  public override void set_up_tp ()
    {
      /* don't create accounts - we do that per-test */
      ((!) this.tp_backend).set_up ();
    }

  public override void set_up_kf ()
    {
      /* don't set up - we do it per-test */
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

      var tp_backend = (!) this.tp_backend;
      ((!) this.kf_backend).set_up ("");

      void* account1_handle = tp_backend.add_account ("protocol",
          "me@example.com", "cm", "account");
      void* account2_handle = tp_backend.add_account ("protocol",
          "me2@example.com", "cm", "account2");

      /* IDs of the individuals we expect to see. */
      var default_individuals = new HashSet<string> ();
      foreach (var id in this._default_personas)
        {
          default_individuals.add (Checksum.compute_for_string (
              ChecksumType.SHA1, iid_prefix + id));
        }

      /* Work on a copy of the set of individuals so we can mangle it. We keep
       * one copy of the set for the individuals_changed signal, and one for
       * the individuals_changed_detailed signal so that we can compare their
       * behaviour. */
      HashSet<string> expected_individuals = new HashSet<string> ();
      var expected_individuals_detailed = new HashSet<string> ();
      foreach (var id in default_individuals)
        {
          expected_individuals.add (id);
          expected_individuals_detailed.add (id);
        }

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var removed = changes.get_keys ();
          var added = changes.get_values ();

          this._test_iid_individuals_changed (true, added, removed,
              default_individuals, expected_individuals_detailed);
        });
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          this._test_iid_individuals_changed (false, added, removed,
              default_individuals, expected_individuals);
        });

      /* Kill the main loop after a few seconds. If there are still individuals
       * in the set of expected individuals, the aggregator has either failed or
       * been too slow (which we can consider to be failure). */

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

      TestUtils.loop_run_with_timeout (main_loop);

      /* We should have enumerated exactly the individuals in the set */
      assert (expected_individuals.size == 0);
      assert (expected_individuals_detailed.size == 0);

      /* Clean up for the next test */
      tp_backend.remove_account (account2_handle);
      tp_backend.remove_account (account1_handle);
      aggregator = null;
    }

  private void _test_iid_individuals_changed (bool detailed,
      Collection<Individual?> added, Set<Individual?> removed,
      Set<string> default_individuals, Set<string> expected_individuals)
    {
      /* If an individual is removed, add them back to the set of expected
       * individuals (if they were originally on it) */
      foreach (Individual i in removed)
        {
          assert (i != null || detailed == true);
          if (i == null)
            {
              continue;
            }

          if (!i.is_user &&
              i.personas.size == 2 &&
              default_individuals.contains (i.id))
            {
              expected_individuals.add (i.id);
            }
        }

      /* If an individual is added (and has been fully linked), remove them
       * from the set of expected individuals. */
      foreach (Individual i in added)
        {
          assert (i != null || detailed == true);
          if (i == null)
            {
              continue;
            }

          var personas = i.personas;

          /* We're not testing the user here */
          if (!i.is_user && personas.size == 2)
            {
              assert (expected_individuals.remove (i.id));

              string iid = null;
              foreach (var persona in personas)
                {
                  if (iid != null)
                    {
                      assert (persona.iid == iid);
                    }
                  else
                    {
                      iid = persona.iid;
                    }
                }
            }
        }
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

      ((!) this.kf_backend).set_up ("[0]\n" +
          "protocol=travis@example.com;olivier@example.com;" +
              "guillaume@example.com;sjoerd@example.com\n" +
          "[1]\n" +
          "protocol=christian@example.com;wim@example.com;" +
              "helen@example.com;geraldine@example.com");

      this.account_handle = ((!) this.tp_backend).add_account ("protocol",
          "me@example.com", "cm", "account");

      /* We expect two non-user individuals (each containing four Telepathy
       * personas and one key-file persona) */
      weak Individual individual1 = null;
      weak Individual individual1_detailed = null;
      weak Individual individual2 = null;
      weak Individual individual2_detailed = null;

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var removed = changes.get_keys ();
          var added = changes.get_values ();

          this._test_linkable_properties_individuals_changed (true, 5, added,
              removed, ref individual1_detailed, ref individual2_detailed);
        });
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          this._test_linkable_properties_individuals_changed (false, 5, added,
              removed, ref individual1, ref individual2);
        });

      /* Kill the main loop after a few seconds. If there are still individuals
       * in the set of expected individuals, the aggregator has either failed or
       * been too slow (which we can consider to be failure). */

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

      TestUtils.loop_run_with_timeout (main_loop);

      /* Verify the two individuals we should have */
      assert (individual1 != null);
      assert (individual1_detailed != null);
      assert (individual2 != null);
      assert (individual2_detailed != null);

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
      bool detailed_swapped = false;
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

          var found_detailed = false;
          foreach (var pd in individual1_detailed.personas)
            {
              if (pd.uid == p.uid)
                {
                  found_detailed = true;
                }
            }

          if (!found_detailed && !detailed_swapped)
            {
              /* Swap individual1_detailed and individual2_detailed in the case they
               * did not appear in the same order in normal and detailed signals */
              weak Individual tmp = individual1_detailed;
              individual1_detailed = individual2_detailed;
              individual2_detailed = tmp;
              detailed_swapped = true;

              foreach (var pd in individual1_detailed.personas)
                {
                  if (pd.uid == p.uid)
                    {
                      found_detailed = true;
                    }
                }
            }

          assert (found_detailed == true);
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

          var found_detailed = false;
          foreach (var pd in individual2_detailed.personas)
            {
              if (pd.uid == p.uid)
                {
                  found_detailed = true;
                }
            }
          assert (found_detailed == true);
        }

      assert (set_in_use.size == 0);

      /* Clean up for the next test */
      ((!) this.tp_backend).remove_account ((!) this.account_handle);
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

      ((!) this.kf_backend).set_up ("[0]\n" +
          "protocol=travis@example.com;olivier@example.com;" +
              "guillaume@example.com;sjoerd@example.com\n" +
          "protocol2=christian@example.com;wim@example.com;" +
              "helen@example.com;geraldine@example.com\n" +
          "[1]\n" +
          "protocol=christian@example.com;wim@example.com;" +
              "helen@example.com;geraldine@example.com\n" +
          "protocol2=travis@example.com;olivier@example.com;" +
              "guillaume@example.com;sjoerd@example.com");

      var tp_backend = (!) this.tp_backend;
      void* account1_handle = tp_backend.add_account ("protocol",
          "me@example.com", "cm", "account");
      void* account2_handle = tp_backend.add_account ("protocol2",
          "me@example.com", "cm", "account2");

      /* We expect two non-user individuals (each containing four Telepathy
       * personas and one key-file persona) */
      weak Individual individual1 = null;
      weak Individual individual1_detailed = null;
      weak Individual individual2 = null;
      weak Individual individual2_detailed = null;

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var removed = changes.get_keys ();
          var added = changes.get_values ();

          this._test_linkable_properties_individuals_changed (true, 9, added,
              removed, ref individual1_detailed, ref individual2_detailed);
        });
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          this._test_linkable_properties_individuals_changed (false, 9, added,
              removed, ref individual1, ref individual2);
        });

      /* Kill the main loop after a few seconds. If there are still individuals
       * in the set of expected individuals, the aggregator has either failed or
       * been too slow (which we can consider to be failure). */

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

      TestUtils.loop_run_with_timeout (main_loop);

      /* Verify the two individuals we should have */
      assert (individual1 != null);
      assert (individual1_detailed != null);
      assert (individual2 != null);
      assert (individual2_detailed != null);

      /* Work on a copy of the set of individuals so we can mangle it.
       * We expect the two individuals to each have exactly one of the default
       * personas, half of which should come from one persona store, and half
       * from a different persona store. */
      var expected_personas1 = new HashSet<string> ();
      var expected_personas1_detailed = new HashSet<string> ();
      var expected_personas2 = new HashSet<string> ();
      var expected_personas2_detailed = new HashSet<string> ();
      foreach (var id in this._default_personas)
        {
          expected_personas1.add (id);
          expected_personas1_detailed.add (id);
          expected_personas2.add (id);
          expected_personas2_detailed.add (id);
        }

      foreach (var p in individual1.personas)
        {
          assert (expected_personas1.remove (p.display_id) ||
              p.display_id == "0" || p.display_id == "1");
        }

      assert (expected_personas1.size == 0);

      foreach (var p in individual1_detailed.personas)
        {
          assert (expected_personas1_detailed.remove (p.display_id) ||
              p.display_id == "0" || p.display_id == "1");
        }

      assert (expected_personas1_detailed.size == 0);

      foreach (var p in individual2.personas)
        {
          assert (expected_personas2.remove (p.display_id) ||
              p.display_id == "0" || p.display_id == "1");
        }

      assert (expected_personas2.size == 0);

      foreach (var p in individual2_detailed.personas)
        {
          assert (expected_personas2_detailed.remove (p.display_id) ||
              p.display_id == "0" || p.display_id == "1");
        }

      assert (expected_personas2_detailed.size == 0);

      /* Clean up for the next test */
      tp_backend.remove_account (account2_handle);
      tp_backend.remove_account (account1_handle);
      aggregator = null;
    }

  private void _test_linkable_properties_individuals_changed (bool detailed,
      uint num_personas, Collection<Individual?> added,
      Set<Individual?> removed, ref weak Individual? individual1,
      ref weak Individual? individual2)
    {
      foreach (Individual i in removed)
        {
          assert (i != null || detailed == true);
          if (i == null)
            {
              continue;
            }

          if (!i.is_user && i.personas.size == num_personas)
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
                  GLib.critical ("Unknown %u-persona individual: %s",
                      num_personas, i.id);
                  assert_not_reached ();
                }
            }
        }

      foreach (Individual i in added)
        {
          assert (i != null || detailed == true);
          if (i == null)
            {
              continue;
            }

          if (!i.is_user && i.personas.size == num_personas)
            {
              if (individual1 == null && individual2 != i)
                {
                  individual1 = i;
                }
              else if (individual2 == null && individual1 != i)
                {
                  individual2 = i;
                }
              else if (individual1 != i && individual2 != i)
                {
                  GLib.critical ("Unknown %u-persona individual: %s",
                      num_personas, i.id);
                  assert_not_reached ();
                }
            }
        }
    }

  /* Test that the personas which have the is-user property marked as true
   * are linked together, even if they're from different persona stores. */
  public void test_user ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      ((!) this.kf_backend).set_up ("");

      var tp_backend = (!) this.tp_backend;
      void* account1_handle = tp_backend.add_account ("protocol",
          "me@example.com", "cm", "account");
      void* account2_handle = tp_backend.add_account ("protocol",
          "me2@example.com", "cm", "account2");

      Individual user_individual = null;
      Individual user_individual_detailed = null;

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
      var individuals_changed_detailed_id =
          aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var removed = changes.get_keys ();
          var added = changes.get_values ();

          this._test_user_individuals_changed (true, added, removed,
              ref user_individual_detailed);
        });
      var individuals_changed_id =
          aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          this._test_user_individuals_changed (false, added, removed,
              ref user_individual);
        });

      /* Kill the main loop after a few seconds. If there are still individuals
       * in the set of expected individuals, the aggregator has either failed or
       * been too slow (which we can consider to be failure). */

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

      TestUtils.loop_run_with_timeout (main_loop);

      /* The user exported by the aggregator should be the same as the one
       * we've kept track of */
      assert (aggregator.user == user_individual);
      assert (aggregator.user == user_individual_detailed);

      /* The user individual should comprise personas from the two accounts */
      assert (user_individual.personas.size == 2);
      assert (user_individual_detailed.personas.size == 2);

      var display_ids = new HashSet<string> ();
      foreach (var persona in user_individual.personas)
        {
          display_ids.add (persona.display_id);
        }

      assert (display_ids.contains ("me@example.com") &&
          display_ids.contains ("me2@example.com"));

      var display_ids_detailed = new HashSet<string> ();
      foreach (var persona in user_individual_detailed.personas)
        {
          display_ids_detailed.add (persona.display_id);
        }

      assert (display_ids_detailed.contains ("me@example.com") &&
          display_ids_detailed.contains ("me2@example.com"));

      aggregator.disconnect (individuals_changed_id);
      aggregator.disconnect (individuals_changed_detailed_id);

      /* Clean up for the next test */
      tp_backend.remove_account (account2_handle);
      tp_backend.remove_account (account1_handle);
      aggregator = null;
    }

  private void _test_user_individuals_changed (bool detailed,
      Collection<Individual?> added, Set<Individual?> removed,
      ref Individual? user_individual)
    {
      /* Keep track of the user individual */
      foreach (Individual i in removed)
        {
          assert (i != null || detailed == true);
          if (i == null)
            {
              continue;
            }

          if (i.is_user)
            {
              assert (user_individual == i);
              user_individual = null;
            }
        }

      foreach (Individual i in added)
        {
          assert (i != null || detailed == true);
          if (i == null)
            {
              continue;
            }

          if (i.is_user)
            {
              assert (user_individual == null);
              user_individual = i;
            }
        }
    }

  /* Test that the personas from an untrusted store (e.g. one which represents
   * an IRC connection in Telepathy) are not linked, even if they would
   * otherwise be linked due to their IIDs. */
  public void test_untrusted_store ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      ((!) this.kf_backend).set_up ("");

      var tp_backend = (!) this.tp_backend;
      void* account1_handle = tp_backend.add_account ("irc",
          "me@example.com", "cm", "account");
      void* account2_handle = tp_backend.add_account ("irc",
          "me2@example.com", "cm", "account2");

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
      var individuals_changed_detailed_id =
          aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var removed = changes.get_keys ();
          var added = changes.get_values ();

          this._test_untrusted_store_individuals_changed (true, added, removed);
        });
      var individuals_changed_id =
          aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          this._test_untrusted_store_individuals_changed (false, added,
              removed);
        });

      /* Kill the main loop after a few seconds. If there are still individuals
       * in the set of expected individuals, the aggregator has either failed or
       * been too slow (which we can consider to be failure). */

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

      TestUtils.loop_run_with_timeout (main_loop);

      aggregator.disconnect (individuals_changed_id);
      aggregator.disconnect (individuals_changed_detailed_id);

      /* Clean up for the next test */
      tp_backend.remove_account (account2_handle);
      tp_backend.remove_account (account1_handle);
      aggregator = null;
    }

  private void _test_untrusted_store_individuals_changed (bool detailed,
      Collection<Individual?> added, Set<Individual?> removed)
    {
      /* Assert that no aggregation occurs at all (except with the
       * personas for the user). */
      foreach (Individual i in removed)
        {
          assert (i != null || detailed == true);
          if (i == null)
            {
              continue;
            }

          assert (i.is_user || i.personas.size == 1);
        }

      foreach (Individual i in added)
        {
          assert (i != null || detailed == true);
          if (i == null)
            {
              continue;
            }

          assert (i.is_user || i.personas.size == 1);
        }
    }

  private enum IndividualState
    {
      ADDED, /* Individual has been added to aggregator but not removed */
      REMOVED, /* removed from aggregator but not yet finalised */
      FINALISED /* removed from aggregator and finalised */
    }

  /* Test that individuals are refcounted correctly when added to and removed
   * from the individual aggregator, and when linked together (in a basic
   * fashion).
   *
   * We do this by tracking all the individuals added to and removed from the
   * individual aggregator, and checking that they're all finalised at the
   * correct times by maintaining weak references to them. */
  public void test_linked_individual_refcounting ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      ((!) this.kf_backend).set_up ("[0]\n" +
          "protocol=travis@example.com;olivier@example.com;" +
              "guillaume@example.com;sjoerd@example.com\n" +
          "[1]\n" +
          "protocol=christian@example.com;wim@example.com;" +
              "helen@example.com;geraldine@example.com");

      this.account_handle = ((!) this.tp_backend).add_account ("protocol",
          "me@example.com", "cm", "account");

      /* Weakly track all the individuals we see, and assert that they're
       * all finalised correctly. This is a map from the Individual to their
       * state. We use this to track when the Individuals are finalised.
       *
       * Note that Individuals + their IDs are used as the keys, rather than
       * just the Individuals' IDs. This is because it's valid for several
       * different instances of Folks.Individual to have the same ID (as long as
       * they contain the same Personas). However, it's also possible for the
       * allocator to legitimately re-use an address during a test for an
       * individual with a different ID. This is fine, since this is a
       * refcounting test, so is entirely concerned with specific object
       * instances. */
      var individuals_map = new HashMap<string, IndividualState> ();

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
      var aggregator_is_finalising = false;

      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          foreach (Individual i in removed)
            {
              var key = "%s:%p".printf (i.id, i);

              assert (individuals_map.has_key (key) == true);
              assert (individuals_map.get (key) == IndividualState.ADDED);

              individuals_map.set (key, IndividualState.REMOVED);
            }

          foreach (Individual i in added)
            {
              var key = "%s:%p".printf (i.id, i);

              assert (individuals_map.has_key (key) == false);

              individuals_map.set (key, IndividualState.ADDED);

              /* Weakly reference the Individual so we can track when it's
               * finalised. We normally assert that an Individual is removed
               * from the aggregator before it's finalised, but if we're
               * shutting the aggregator down we allow Individuals to
               * transition straight from ADDED to FINALISED. */
              i.weak_ref ((obj) =>
                {
                  unowned Individual ind = (Individual) obj;
                  var weak_key = "%s:%p".printf (ind.id, ind);

                  assert (individuals_map.has_key (weak_key) == true);
                  var state = individuals_map.get (weak_key);
                  assert (state == IndividualState.REMOVED ||
                      (aggregator_is_finalising == true &&
                          state == IndividualState.ADDED));

                  individuals_map.set (weak_key, IndividualState.FINALISED);
                });
            }
        });

      /* Kill the main loop after a few seconds. We can assume that we've
       * reached a quiescent state by this point. */

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

      TestUtils.loop_run_with_timeout (main_loop);

      /* Check that all Individuals are either ADDED or FINALISED. There should
       * be no Individuals which are REMOVED (but not yet finalised). */
      var iter = individuals_map.map_iterator ();
      while (iter.next () == true)
        {
          var state = iter.get_value ();
          assert (state == IndividualState.ADDED ||
                  state == IndividualState.FINALISED);
        }

      /* Remove all the individuals (hopefully) */
      ((!) this.tp_backend).remove_account ((!) account_handle);
      ((!) this.kf_backend).tear_down ();
      aggregator_is_finalising = true;
      aggregator = null;

      /* Kill the main loop after a few seconds. We can assume that we've
       * reached another quiescent state by this point. */

      TestUtils.loop_run_with_timeout (main_loop);

      /* Now that the backends have been finalised, all the Individuals should
       * have been finalised too. */
      iter = individuals_map.map_iterator ();
      while (iter.next () == true)
        {
          assert (iter.get_value () == IndividualState.FINALISED);
        }
    }

  /* Test that if an individual contains a persona with a given writeable
   * property, calling
   * IndividualAggregator.ensure_individual_property_writeable() on that
   * individual and property returns the existing persona.
   * We do this by creating a single key file persona and ensuring that its
   * alias property is writeable. */
  public void test_ensure_individual_property_writeable_trivial ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      ((!) this.kf_backend).set_up ("[0]\n" +
          "protocol=travis@example.com\n");

      Individual? individual = null;

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          assert (changes.size == 1);

          foreach (var removed in changes.get_keys ())
            {
              assert (removed == null);

              foreach (var i in changes.get (removed))
                {
                  assert (i != null);
                  assert (individual == null);

                  individual = i;
                  main_loop.quit ();
                }
            }
        });

      /* Kill the main loop after a few seconds. */

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

      TestUtils.loop_run_with_timeout (main_loop);

      /* Check we've got the individual we want */
      assert (individual != null);

      Persona? persona = null;
      foreach (var p in individual.personas)
        {
          persona = p;
          break;
        }

      /* Try and ensure that the alias property is writeable */
      assert (persona != null);
      assert ("alias" in persona.writeable_properties);

      Persona? writeable_persona = null;

      /* Kill the main loop after a few seconds. */

      Idle.add (() =>
        {
          aggregator.ensure_individual_property_writeable.begin (individual,
              "alias", (obj, res) =>
            {
              try
                {
                  writeable_persona =
                      aggregator.ensure_individual_property_writeable.end (res);

                  main_loop.quit ();
                }
              catch (Error e1)
                {
                  critical ("Failed to ensure property writeable: %s",
                      e1.message);
                  assert_not_reached ();
                }
            });

          return false;
        });

      TestUtils.loop_run_with_timeout (main_loop);

      assert (writeable_persona != null);
      assert (writeable_persona == persona);

      /* Clean up for the next test */
      aggregator = null;
    }

  /* Test that if an individual doesn't contain a persona with a given
   * writeable property, but a persona store exists which can create personas
   * with that writeable property, calling
   * IndividualAggregator.ensure_individual_property_writeable() on that
   * individual and property will create a new persona and link it to the
   * existing individual.
   * We do this by creating an empty key file store and a normal Telepathy
   * store. We ensure that the im-addresses property of the individual (which
   * contains only a Tpf.Persona) is writeable, which should result in creating
   * a Kf.Persona and linking it to the individual. */
  public void test_ensure_individual_property_writeable_add_persona ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      ((!) this.kf_backend).set_up ("");
      this.account_handle = ((!) this.tp_backend).add_account ("protocol",
          "me@example.com", "cm", "account");

      Individual? individual = null;

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
      var individuals_changed_id =
          aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          foreach (Individual i in added)
            {
              assert (i != null);

              if (i.id == olivier_sha1)
                {
                  assert (individual == null);
                  individual = i;
                  return;
                }
            }

          assert (removed.size == 1);

          foreach (var i in removed)
            {
              assert (i == null);
            }
        });

      /* Kill the main loop after a few seconds. */

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

      TestUtils.loop_run_with_timeout (main_loop);

      /* Check we've got the individual we want */
      assert (individual != null);

      Persona? persona = null;
      foreach (var p in individual.personas)
        {
          persona = p;
          break;
        }

      /* Try and ensure that the im-addresses property is not writeable */
      assert (persona != null);
      assert (!("im-addresses" in persona.writeable_properties));

      Persona? writeable_persona = null;

      /* Remove the signal handler */
      aggregator.disconnect (individuals_changed_id);
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          foreach (Individual i in removed)
            {
              if (i == null)
                {
                  continue;
                }

              assert (individual != null);
              assert (i == individual);
              individual = null;
            }

          foreach (Individual i in added)
            {
              if (i == null)
                {
                  continue;
                }

              var got_tpf = false;
              var got_kf = false;

              /* We can't check for the desired individual by ID, since it's
               * based on a Kf.Persona UID which is randomly generated. Instead,
               * we have to check for the personas themselves. */
              foreach (var p in i.personas)
                {
                  if (p.uid == iid_prefix + "olivier@example.com")
                    {
                      got_tpf = true;
                    }
                  else if (p.store.type_id == "key-file")
                    {
                      got_kf = true;
                    }
                }

              if (got_tpf == true && got_kf == true)
                {
                  individual = i;
                  return;
                }
            }
        });

      /* Kill the main loop after a few seconds. */

      Idle.add (() =>
        {
          aggregator.ensure_individual_property_writeable.begin (individual,
              "im-addresses", (obj, res) =>
            {
              try
                {
                  writeable_persona =
                      aggregator.ensure_individual_property_writeable.end (res);

                  main_loop.quit ();
                }
              catch (Error e1)
                {
                  critical ("Failed to ensure property writeable: %s",
                      e1.message);
                  assert_not_reached ();
                }
            });

          return false;
        });

      TestUtils.loop_run_with_timeout (main_loop);

      assert (writeable_persona != null);
      assert (writeable_persona != persona);

      /* Clean up for the next test */
      individual = null;
      persona = null;
      writeable_persona = null;
      aggregator = null;
    }

  /* Test that if an individual doesn't contain a persona which has a given
   * writeable property, and no persona store exists which can create personas
   * with that writeable property, calling
   * IndividualAggregator.ensure_individual_property_writeable() on that
   * individual and property throws an error.
   * We do this by creating a single key file persona and attempting to ensure
   * that its is-favourite property is writeable. Since the key file backend
   * doesn't support is-favourite, and no other backends are available, this
   * should fail. */
  public void test_ensure_individual_property_writeable_failure ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      ((!) this.kf_backend).set_up ("[0]\n" +
          "protocol=travis@example.com\n");

      Individual? individual = null;

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          assert (changes.size == 1);

          foreach (var removed in changes.get_keys ())
            {
              assert (removed == null);

              foreach (var i in changes.get (removed))
                {
                  assert (i != null);
                  assert (individual == null);

                  individual = i;
                  main_loop.quit ();
                }
            }
        });

      /* Kill the main loop after a few seconds. */

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

      TestUtils.loop_run_with_timeout (main_loop);

      /* Check we've got the individual we want */
      assert (individual != null);

      Persona? persona = null;
      foreach (var p in individual.personas)
        {
          persona = p;
          break;
        }

      /* Try and ensure that the is-favourite property is writeable */
      assert (persona != null);
      assert (!("is-favourite" in persona.writeable_properties));

      Persona? writeable_persona = null;

      /* Kill the main loop after a few seconds. */

      Idle.add (() =>
        {
          aggregator.ensure_individual_property_writeable.begin (individual,
              "is-favourite", (obj, res) =>
            {
              try
                {
                  writeable_persona =
                      aggregator.ensure_individual_property_writeable.end (res);
                  assert_not_reached ();
                }
              catch (Error e1)
                {
                  /* We expect this error */
                  if (!(e1 is IndividualAggregatorError.PROPERTY_NOT_WRITEABLE))
                    {
                      critical ("Wrong error received: %s", e1.message);
                      assert_not_reached ();
                    }

                  main_loop.quit ();
                }
            });

          return false;
        });

      TestUtils.loop_run_with_timeout (main_loop);

      assert (writeable_persona == null);

      /* Clean up for the next test */
      aggregator = null;
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new AggregationTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
