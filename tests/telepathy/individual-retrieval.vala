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

public class IndividualRetrievalTests : TpfTest.TestCase
{
  private HashSet<string> default_individuals;

  private static string iid_prefix =
      "telepathy:/org/freedesktop/Telepathy/Account/cm/protocol/account:";

  public IndividualRetrievalTests ()
    {
      base ("IndividualRetrieval");

      /* IDs of the individuals we expect to see. */
      this.default_individuals = new HashSet<string> ();

      default_individuals.add (Checksum.compute_for_string (ChecksumType.SHA1,
          iid_prefix + "me@example.com"));
      default_individuals.add (Checksum.compute_for_string (ChecksumType.SHA1,
          iid_prefix + "travis@example.com"));
      default_individuals.add (Checksum.compute_for_string (ChecksumType.SHA1,
          iid_prefix + "guillaume@example.com"));
      default_individuals.add (Checksum.compute_for_string (ChecksumType.SHA1,
          iid_prefix + "olivier@example.com"));
      default_individuals.add (Checksum.compute_for_string (ChecksumType.SHA1,
          iid_prefix + "sjoerd@example.com"));
      default_individuals.add (Checksum.compute_for_string (ChecksumType.SHA1,
          iid_prefix + "geraldine@example.com"));
      default_individuals.add (Checksum.compute_for_string (ChecksumType.SHA1,
          iid_prefix + "helen@example.com"));
      default_individuals.add (Checksum.compute_for_string (ChecksumType.SHA1,
          iid_prefix + "wim@example.com"));
      default_individuals.add (Checksum.compute_for_string (ChecksumType.SHA1,
          iid_prefix + "christian@example.com"));

      this.add_test ("aggregator", this.test_aggregator);
      this.add_test ("aggregator:add", this.test_aggregator_add);
    }

  public void test_aggregator ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* work on a copy so we can mangle it */
      HashSet<string> expected_individuals = new HashSet<string> ();
      foreach (var id in this.default_individuals)
        expected_individuals.add (id);

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          foreach (Individual i in added)
            {
              assert (i != null);
              expected_individuals.remove (i.id);
            }

          assert (removed.size == 1);

          foreach (var i in removed)
            {
              assert (i == null);
            }
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
                  GLib.critical ("failed to prepare aggregator: %s",
                    e1.message);
                  assert_not_reached ();
                }
            });

          return false;
        });

      TestUtils.loop_run_with_timeout (main_loop);

      /* We should have enumerated exactly the individuals in the set */
      assert (expected_individuals.size == 0);

      /* necessary to reset the aggregator for the next test */
      aggregator = null;
    }

  public void test_aggregator_add ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      HashSet<string> added_individuals = new HashSet<string> ();
      added_individuals.add ("mister.shake@example.com");
      added_individuals.add ("2wycked@example.com");
      added_individuals.add ("carl-brutananadilewski@example.com");

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();

      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          /* implicitly ignore the default Individuals, since that's covered in
           * other test(s) */
          foreach (Individual i in added)
            {
              assert (i != null);

              /* If the Individual contains a Persona with an ID we provided,
               * mark it as received.
               * This intentionally avoids assuming that the Individual's ID is
               * necessarily related to the ID of any of its Persona(s) */
              foreach (Folks.Persona p in i.personas)
                {
                  if (p is Tpf.Persona)
                    if (added_individuals.remove (((Tpf.Persona) p).display_id))
                      break;
                }
            }

          assert (removed.size == 1);

          foreach (var i in removed)
            {
              assert (i == null);
            }
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
              foreach (var backend in backend_store.enabled_backends.values)
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

                  foreach (var store in backend.persona_stores.values)
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

      TestUtils.loop_run_with_timeout (main_loop);

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
          var ids_remaining = new HashSet<string> ();
          foreach (var contact_id in ids_add)
            ids_remaining.add (contact_id);

          Idle.add (() =>
            {
              var try_again = false;

              foreach (var id in ids_remaining)
                {
                  var details = new HashTable<string, GLib.Value?> (str_hash, str_equal);
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

  var tests = new IndividualRetrievalTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
