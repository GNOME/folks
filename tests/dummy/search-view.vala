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
 * Authors: Travis Reitter <travis.reitter@collabora.co.uk>
 *          Philip Withnall <philip.withnall@collabora.co.uk>
 */

using Gee;
using Folks;
using FolksDummy;

public class SearchViewTests : DummyTest.TestCase
{
  /* NOTE: The contents of these variables needs to match their names */
  private const string _FULL_NAME = "Sterling Mallory Archer";
  private const string _FULL_NAME_TOKEN = "Archer";
  private const string _FULL_NAME_TOKEN_LC = "archer";
  private const string _FULL_NAME_SUBTOKEN = "cher";
  private const string _FULL_NAME_PREFIX = "arch";
  private const string _NON_MATCHING_PARTIAL_NAME = "Stimpson";
  private const string _PHONE_NUMBER = "+1-800-867-5309";
  private const string _EQUIVALENT_PHONE_NUMBER = "867-5309";

  public SearchViewTests ()
    {
      base ("SearchView");

      this.add_test ("simple search results", this.test_simple_search_results);
      this.add_test ("search before and after", this.test_search_before_after);
      this.add_test ("match each type of field", this.test_match_each_field);
      this.add_test ("individual changes", this.test_individual_changes);
      this.add_test ("query changes", this.test_query_changes);
    }

  public override void configure_primary_store ()
    {
      base.configure_primary_store ();
      this.dummy_persona_store.reach_quiescence ();
    }

  struct SimpleTestVector
    {
      public unowned string query;
      public unowned string expected_individuals;  /* comma separated, ordered */
    }

  public void test_simple_search_results ()
    {
      /* Test vectors. */
      const SimpleTestVector[] vectors =
        {
          { "Ali", "persona1" },
          { "Ali Avo", "persona1" },
          { "Arachnid", "persona2" },
          { "unmatched", "" },
          { "archer", "persona0" },
          { "arch", "persona0" },
          /* Non-prefix match. */
          { "cher", "" },
          /* Phone numbers. */
          { "867-5309", "persona0" },
          { "+1-800-867-5309", "persona0" },
          { "+1-800", "persona0" },
          { "8675309", "persona0" },
          { "1800", "persona0" },
          /* Test transliteration only applies to the individual’s tokens. */
          { "Al", "persona1,persona3" },
          { "Ál", "persona3" },
          /* Test different Unicode normalisations and transliterations. */
          { "Pan", "persona3" },
          { "Pa\xc3\xb1", "persona3" },
          { "Pa\x6e\xcc\x83", "persona3" },
          /* Sort stability. */
          { "A", "persona1,persona2,persona0,persona3" },
          { "Al", "persona1,persona3" },
          { "Ali", "persona1" },
        };

      /* Set up a dummy persona store. */
      var persona0 = this._generate_main_persona ();
      var persona1 = new FullPersona (this.dummy_persona_store, "persona1");
      var persona2 = new FullPersona (this.dummy_persona_store, "persona2");
      var persona3 = new FullPersona (this.dummy_persona_store, "persona3");

      persona1.update_full_name ("Alice Avogadro");
      persona2.update_full_name ("Artemis Arachnid");
      persona3.update_full_name ("Álvaro Pañuelo");

      var personas = new HashSet<FolksDummy.Persona> ();
      personas.add (persona0);
      personas.add (persona1);
      personas.add (persona2);
      personas.add (persona3);

      this.dummy_persona_store.register_personas (personas);

      /* Set up the aggregator. */
      var aggregator = IndividualAggregator.dup ();

      foreach (var vector in vectors)
        {
          /* Create a set of the individuals we expect. */
          var inds = vector.expected_individuals.split (",");

          this._test_simple_search_results_single (aggregator, vector.query,
              inds);
        }

      aggregator = null;
    }

  /* May modify @expected_individuals. */
  private void _test_simple_search_results_single (
      IndividualAggregator aggregator,
      string query,
      string[] expected_individuals)
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Set up the query and search view. */
      var fields = Query.MATCH_FIELDS_NAMES;
      foreach (var field in Query.MATCH_FIELDS_ADDRESSES)
          fields += field;
      var simple_query = new SimpleQuery (query, fields);
      var search_view = new SearchView (aggregator, simple_query);

      search_view.prepare.begin ((s, r) =>
        {
          try
            {
              search_view.prepare.end (r);
              main_loop.quit ();
            }
          catch (GLib.Error e1)
            {
              error ("Failed to prepare search view: %s", e1.message);
            }
        });

      /* Run the test for a few seconds and fail if the timeout is exceeded. */
      TestUtils.loop_run_with_timeout (main_loop);

      /* Check the individuals, in order. */
      var iter = search_view.individuals.iterator ();
      foreach (var expected_persona_id in expected_individuals)
        {
          assert (iter.next ());
          var ind = iter.get ();

          assert (ind.personas.size == 1);
          foreach (var persona in ind.personas)
            {
              assert (expected_persona_id == persona.display_id);
            }
        }

      assert (!iter.has_next ());

      search_view.unprepare.begin ((s, r) =>
        {
          try
            {
              search_view.unprepare.end (r);
              main_loop.quit ();
            }
          catch (GLib.Error e1)
            {
              error ("Failed to unprepare search view: %s", e1.message);
            }
        });
      TestUtils.loop_run_with_timeout (main_loop);

      search_view.aggregator.unprepare.begin ((s, r) =>
        {
          try
            {
              search_view.aggregator.unprepare.end (r);
              main_loop.quit ();
            }
          catch (GLib.Error e2)
            {
              error ("Failed to unprepare aggregator: %s", e2.message);
            }
        });
      TestUtils.loop_run_with_timeout (main_loop);

      search_view = null;
    }

  public void test_search_before_after ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var expected_matches = new HashSet<string> ();
      var expected_non_matches = new HashSet<string> ();
      var unexpected_matches = new HashSet<string> ();

      /* Add a first persona who will be matched. */
      var personas = new HashSet<FolksDummy.Persona> ();
      personas.add (this._generate_main_persona ());

      /* Add a second persona, not expected to match the query. */
      var persona1 = new FullPersona (this.dummy_persona_store, "persona1");

      persona1.update_full_name ("Lana Kane");

      var email_addresses = new HashSet<EmailFieldDetails> ();
      email_addresses.add (new EmailFieldDetails ("lana@isis.secret"));
      persona1.update_email_addresses (email_addresses);

      personas.add (persona1);

      /* Perform a single-token search which will match two Individuals (one at
       * first, then another added after preparing the SearchView/Aggregator) */
      expected_matches.add ("persona0");
      this.dummy_persona_store.register_personas (personas);

      var store = BackendStore.dup ();
      store.prepare.begin ((s, r) =>
        {
          store.prepare.end (r);
          main_loop.quit ();
        });

      TestUtils.loop_run_with_timeout (main_loop);

      var aggregator = IndividualAggregator.dup ();

      var fields = Query.MATCH_FIELDS_NAMES;
      foreach (var field in Query.MATCH_FIELDS_ADDRESSES)
          fields += field;
      var query = new SimpleQuery ("Mallory", fields);
      var search_view = new SearchView (aggregator, query);

      var handler_id = search_view.individuals_changed_detailed.connect ((added, removed) =>
        {
          this._individuals_added (added, main_loop,
              expected_matches, expected_non_matches, unexpected_matches);
          this._individuals_removed (removed, main_loop,
              expected_matches, expected_non_matches, unexpected_matches);
        });

      search_view.prepare.begin ((s, r) =>
        {
          try
            {
              search_view.prepare.end (r);
              main_loop.quit ();
            }
          catch (GLib.Error e)
            {
              GLib.error ("Error when calling prepare: %s", e.message);
            }
        });

      TestUtils.loop_run_with_timeout (main_loop);

      /* Add a match after the initial set to ensure we handle both existing and
       * added Individuals in the SearchView */
      var persona2 = new FullPersona (this.dummy_persona_store, "persona2");

      persona2.update_full_name ("Mallory Archer");

      email_addresses = new HashSet<EmailFieldDetails> ();
      email_addresses.add (new EmailFieldDetails ("mallory@isis.secret"));
      persona2.update_email_addresses (email_addresses);

      personas = new HashSet<FolksDummy.Persona> ();
      personas.add (persona2);
      expected_matches.add ("persona2");

      this.dummy_persona_store.register_personas (personas);

      assert (expected_matches.size == 0);
      foreach (var unexpected_match in unexpected_matches)
          assert (!(unexpected_match in expected_non_matches));

      search_view.disconnect (handler_id);

      /* Perform a multi-token search which will match fewer Individual(s) */
      fields = Query.MATCH_FIELDS_NAMES;
      foreach (var field in Query.MATCH_FIELDS_ADDRESSES)
          fields += field;

      /* the query string tokens are intentionally out-of-order, in different
       * case, and contain extra spaces */
      query = new SimpleQuery (" mallorY   sterling   ", fields);
      search_view = new SearchView (aggregator, query);
      this._test_search_with_view_async ("persona0", null, search_view);
    }

  public void test_match_each_field ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Add contacts with a known value for each property; then, perform a
       * search that only matches that value and confirm. */

      /* NOTE: each contact added here will only count if it has a test below */
      var personas = new HashSet<FolksDummy.Persona> ();
      personas.add (this._generate_test_contact ("full-name",
          (p) => { p.update_full_name ("full_name"); }));
      personas.add (this._generate_test_contact ("nickname",
          (p) => { p.update_nickname ("nickname"); }));
      /* This fills in our generated value into ContactName.family, but that's
       * fine for our purposes */
      personas.add (this._generate_test_contact ("structured-name", (p) =>
        {
          p.update_structured_name (new StructuredName ("structured_name", null,
              null, null, null));
        }));
      personas.add (this._generate_test_contact ("email-addresses", (p) =>
        {
          var email_addresses = new HashSet<EmailFieldDetails> ();
          email_addresses.add (new EmailFieldDetails ("email_addresses"));
          p.update_email_addresses (email_addresses);
        }));
      personas.add (this._generate_test_contact ("im-addresses", (p) =>
        {
          var im_addresses = new HashMultiMap<string, ImFieldDetails> ();
          im_addresses.set ("jabber", new ImFieldDetails ("im_addresses"));
          p.update_im_addresses (im_addresses);
        }));
      personas.add (this._generate_test_contact ("phone-numbers", (p) =>
        {
          var phone_numbers = new HashSet<PhoneFieldDetails> ();
          phone_numbers.add (new PhoneFieldDetails ("phone_numbers"));
          p.update_phone_numbers (phone_numbers);
        }));
      personas.add (this._generate_test_contact ("postal-addresses", (p) =>
        {
          var postal_addresses = new HashSet<PostalAddressFieldDetails> ();
          var pa = new PostalAddress (null, null, "postal_addresses",
              null, null, null, null, null, null);
          postal_addresses.add (new PostalAddressFieldDetails (pa));
          p.update_postal_addresses (postal_addresses);
        }));
      personas.add (this._generate_test_contact ("web-service-addresses", (p) =>
        {
          var wsa = new HashMultiMap<string, WebServiceFieldDetails> (
              null, null,
              AbstractFieldDetails.hash_static,
              AbstractFieldDetails.equal_static);
          wsa.set ("twitter",
              new WebServiceFieldDetails ("web_service_addresses"));
          p.update_web_service_addresses (wsa);
        }));
      personas.add (this._generate_test_contact ("urls", (p) =>
        {
          var urls = new HashSet<UrlFieldDetails> ();
          urls.add (new UrlFieldDetails ("urls"));
          p.update_urls (urls);
        }));
      personas.add (this._generate_test_contact ("groups", (p) =>
        {
          var groups = new HashSet<string> ();
          groups.add ("groups");
          p.update_groups (groups);
        }));
      personas.add (this._generate_test_contact ("notes", (p) =>
        {
          var notes = new HashSet<NoteFieldDetails> ();
          notes.add (new NoteFieldDetails ("notes"));
          p.update_notes (notes);
        }));
      personas.add (this._generate_test_contact ("roles", (p) =>
        {
          var roles = new HashSet<RoleFieldDetails> ();
          var role = new Role ("roles");
          roles.add (new RoleFieldDetails (role));
          p.update_roles (roles);
        }));

      /* Prepare a backend store. */
      var backend_store = BackendStore.dup ();

      backend_store.prepare.begin ((s, r) =>
        {
          backend_store.prepare.end (r);
          main_loop.quit ();
        });

      TestUtils.loop_run_with_timeout (main_loop);

      this.dummy_persona_store.register_personas (personas);

      /* Prepare the aggregator. */
      var aggregator = IndividualAggregator.dup ();

      aggregator.prepare.begin ((s, r) =>
        {
          try
            {
              aggregator.prepare.end (r);
              main_loop.quit ();
            }
          catch (GLib.Error e)
            {
              error ("Failed to prepare aggregator: %s", e.message);
            }
        });

      TestUtils.loop_run_with_timeout (main_loop);

      /* NOTE: every test here requires an added persona above. */
      this._test_match_each_field_search_for_prop_name (main_loop, aggregator,
          "full-name", "full_name");
      this._test_match_each_field_search_for_prop_name (main_loop, aggregator,
          "nickname", "nickname");
      this._test_match_each_field_search_for_prop_name (main_loop, aggregator,
          "structured-name", "structured_name");
      this._test_match_each_field_search_for_prop_name (main_loop, aggregator,
          "email-addresses", "email_addresses");
      this._test_match_each_field_search_for_prop_name (main_loop, aggregator,
          "im-addresses", "im_addresses");
      this._test_match_each_field_search_for_prop_name (main_loop, aggregator,
          "phone-numbers", "phone_numbers");
      this._test_match_each_field_search_for_prop_name (main_loop, aggregator,
          "postal-addresses", "postal_addresses");
      this._test_match_each_field_search_for_prop_name (main_loop, aggregator,
          "web-service-addresses", "web_service_addresses");
      this._test_match_each_field_search_for_prop_name (main_loop, aggregator,
          "urls", "urls");
      this._test_match_each_field_search_for_prop_name (main_loop, aggregator,
          "notes", "notes");
      this._test_match_each_field_search_for_prop_name (main_loop, aggregator,
          "roles", "roles");
    }

  private delegate void GeneratePersonaFunc (FullPersona persona);

  private FullPersona _generate_test_contact (string contact_id,
      GeneratePersonaFunc generate_persona)
    {
      var persona = new FullPersona (this.dummy_persona_store, contact_id);

      persona.update_full_name (contact_id);
      generate_persona (persona);

      return persona;
    }

  private void _test_match_each_field_search_for_prop_name (MainLoop main_loop,
      IndividualAggregator aggregator, string prop_name, string query)
    {
      var expected_matches = new HashSet<string> ();
      var expected_non_matches = new HashSet<string> ();
      var unexpected_matches = new HashSet<string> ();

      expected_matches.add (prop_name);

      string[] fields = { prop_name };
      var simple_query = new SimpleQuery (query, fields);
      var search_view = new SearchView (aggregator, simple_query);

      var handler_id = search_view.individuals_changed_detailed.connect ((added, removed) =>
        {
          this._individuals_added (added, main_loop,
              expected_matches, expected_non_matches, unexpected_matches);
          this._individuals_removed (removed, main_loop,
              expected_matches, expected_non_matches, unexpected_matches);
        });

      search_view.prepare.begin ((s, r) =>
        {
          try
            {
              search_view.prepare.end (r);
            }
          catch (GLib.Error e)
            {
              error ("Error when calling prepare: %s", e.message);
            }
        });

      TestUtils.loop_run_with_timeout (main_loop);
      assert (expected_matches.size == 0);

      search_view.disconnect (handler_id);
    }

  public void test_individual_changes ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      var personas = new HashSet<FolksDummy.Persona> ();
      personas.add (this._generate_main_persona ());

      this.dummy_persona_store.register_personas (personas);

      var backend_store = BackendStore.dup ();
      backend_store.prepare.begin ((s, r) =>
        {
          backend_store.prepare.end (r);
          main_loop.quit ();
        });

      TestUtils.loop_run_with_timeout (main_loop);

      var aggregator = IndividualAggregator.dup ();

      /*
       * Match original full name
       */
      var query = new SimpleQuery (_FULL_NAME_TOKEN,
          Query.MATCH_FIELDS_NAMES);
      var search_view = new SearchView (aggregator, query);
      this._test_search_with_view_async ("persona0", null, search_view);

      /*
       * Remove match by changing matching field
       */
      var new_non_matching_name = new StructuredName (
          "Cat", "Stimpson", "J.", null, null);
      this._change_user_names.begin (_FULL_NAME,
          new_non_matching_name, aggregator, (s, r) =>
        {
          this._change_user_names.end (r);
          main_loop.quit ();
        });

      TestUtils.loop_run_with_timeout (main_loop);

      query = new SimpleQuery (_FULL_NAME_TOKEN,
          Query.MATCH_FIELDS_NAMES);
      search_view = new SearchView (aggregator, query);
      this._test_search_with_view_async (null, "persona0", search_view);
    }

  public void test_query_changes ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      var personas = new HashSet<FolksDummy.Persona> ();
      personas.add (this._generate_main_persona ());

      this.dummy_persona_store.register_personas (personas);

      var backend_store = BackendStore.dup ();
      backend_store.prepare.begin ((s, r) =>
        {
          backend_store.prepare.end (r);
          main_loop.quit ();
        });

      TestUtils.loop_run_with_timeout (main_loop);

      var aggregator = IndividualAggregator.dup ();

      /*
       * Match original full name
       */
      var query = new SimpleQuery (_FULL_NAME_TOKEN,
          Query.MATCH_FIELDS_NAMES);
      var search_view = new SearchView (aggregator, query);
      this._test_search_with_view_async ("persona0", null, search_view);

      /*
       * Remove match by changing the query
       */
      search_view.query = new SimpleQuery (
          _NON_MATCHING_PARTIAL_NAME, Query.MATCH_FIELDS_NAMES);
      this._test_search_with_view_async (null, "persona0", search_view);

      /*
       * Re-add match by changing the query (to different query than the
       * original but nonetheless also matching our target Individual)
       */
      search_view.query = new SimpleQuery (
          _FULL_NAME_PREFIX, Query.MATCH_FIELDS_NAMES);
      this._test_search_with_view_async ("persona0", null, search_view);

      /*
       * Remove match by changing the query's string
       */
      ((SimpleQuery) search_view.query).query_string =
        _NON_MATCHING_PARTIAL_NAME;
      this._test_search_with_view_async (null, "persona0", search_view);

      /*
       * Re-add match by changing the query's string
       */
      ((SimpleQuery) search_view.query).query_string =
        _FULL_NAME_PREFIX;
      this._test_search_with_view_async ("persona0", null, search_view);
    }

  private void _individuals_added (Collection<Individual> added,
      MainLoop main_loop, Set<string> expected_matches,
      Set<string> expected_non_matches, Set<string> unexpected_matches)
    {
      foreach (Individual i in added)
        {
          assert (i.personas.size == 1);

          /* Using the display ID is a little hacky, since we strictly shouldn't
           * assume anything about…but for the dummy backend, we know it's
           * equal to the contact ID. */
          foreach (var persona in i.personas)
            {
              var removed_expected = false;

              if (persona.display_id in expected_matches)
                {
                  removed_expected =
                      expected_matches.remove (persona.display_id);
                }
              else
                {
                  unexpected_matches.add (persona.display_id);
                }

              if (removed_expected && expected_matches.size == 0)
                  main_loop.quit ();
            }
        }
    }

  private void _individuals_removed (Collection<Individual> removed,
      MainLoop main_loop, Set<string> expected_matches,
      Set<string> expected_non_matches, Set<string> unexpected_matches)
    {
      foreach (Individual i in removed)
        {
          assert (i.personas.size == 1);

          /* Using the display ID is a little hacky, since we strictly shouldn't
           * assume anything about…but for the dummy backend, we know it's
           * equal to the contact ID. */
          foreach (var persona in i.personas)
            {
              /* Note this is asymmetrical to _individuals_added; we don't
               * attempt to re-add entries to expected_matches */

              /* In case our search view removes an Individual later because
               * we've purposely changed it to disqualify it from the query, we
               * shouldn't count the initially "unexpected" match against our
               * test */
              unexpected_matches.remove (persona.display_id);
            }
        }
    }

  /* Generate a single dummy persona. */
  private FullPersona _generate_main_persona ()
    {
      /* Set up a dummy persona store. */
      var persona = new FullPersona (this.dummy_persona_store, "persona0");

      /* NOTE: the full_names of these contacts must be unique */
      persona.update_full_name (_FULL_NAME);
      persona.update_nickname ("Duchess");

      var email_addresses = new HashSet<EmailFieldDetails> ();
      email_addresses.add (new EmailFieldDetails ("sterling@isis.secret"));
      persona.update_email_addresses (email_addresses);

      var phone_numbers = new HashSet<PhoneFieldDetails> ();
      phone_numbers.add (new PhoneFieldDetails (_PHONE_NUMBER));
      persona.update_phone_numbers (phone_numbers);

      return persona;
    }

  private async void _change_user_names (
      string expected_full_name,
      StructuredName non_matching_structured_name,
      IndividualAggregator aggregator)
    {
      var non_matching_full_name = "%s %s %s".printf (
          non_matching_structured_name.given_name,
          non_matching_structured_name.additional_names,
          non_matching_structured_name.family_name);

      foreach (var individual in aggregator.individuals.values)
        {
          if (individual.full_name != expected_full_name)
              continue;

          /* There should be exactly one Persona on this Individual */
          foreach (var persona in individual.personas)
            {
              var name_details = persona as NameDetails;
              assert (name_details != null);

              try
                {
                  yield name_details.change_full_name (
                      non_matching_full_name);
                  yield name_details.change_structured_name (
                      non_matching_structured_name);
                  return;
                }
              catch (PropertyError e)
                {
                  error (e.message);
                }
            }
        }

      assert_not_reached ();
    }

  private void _test_search_with_view_async (
      string? expected_match_display_id,
      string? expected_non_match_display_id,
      SearchView search_view)
    {
      var main_loop = new MainLoop (null, false);
      var expected_matches = new HashSet<string> ();
      var expected_non_matches = new HashSet<string> ();
      var unexpected_matches = new HashSet<string> ();

      if (expected_match_display_id != null)
          expected_matches.add (expected_match_display_id);
      if (expected_non_match_display_id != null)
          expected_non_matches.add (expected_non_match_display_id);

      var handler_id = search_view.individuals_changed_detailed.connect ((added, removed) =>
        {
          this._individuals_added (added, main_loop,
              expected_matches, expected_non_matches, unexpected_matches);
          this._individuals_removed (removed, main_loop,
              expected_matches, expected_non_matches, unexpected_matches);
        });

      /* If there are any matches already, handle those. */
      this._individuals_added (search_view.individuals, main_loop,
          expected_matches, expected_non_matches, unexpected_matches);

      var is_prepared = false;
      search_view.prepare.begin ((s, r) =>
        {
          try
            {
              search_view.prepare.end (r);
              is_prepared = true;

              if (expected_matches.size == 0)
                  main_loop.quit ();
            }
          catch (GLib.Error e)
            {
              error ("Error when calling prepare: %s", e.message);
            }
        });

      if (expected_matches.size > 0 || !is_prepared)
          TestUtils.loop_run_with_timeout (main_loop);

      assert (expected_matches.size == 0);
      foreach (var unexpected_match in unexpected_matches)
          assert (!(unexpected_match in expected_non_matches));

      search_view.disconnect (handler_id);
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new SearchViewTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
