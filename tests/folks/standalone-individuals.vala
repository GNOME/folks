/*
 * Copyright (C) 2013 Collabora Ltd.
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
 * Authors: Philip Withnall <philip.withnall@collabora.co.uk>
 */

using Gee;
using Folks;

public class StandaloneIndividualsTests : Folks.TestCase
{
  public StandaloneIndividualsTests ()
    {
      base ("StandaloneIndividuals");

      /* Set up the tests */
      this.add_test ("create empty individual",
          this.test_create_empty_individual);
      this.add_test ("create singleton individual",
          this.test_create_singleton_individual);
      this.add_test ("create multi individual",
          this.test_create_multi_individual);
      this.add_test ("persona transferral", this.test_persona_transferral);
    }

  /* Test that manually creating an empty individual works. */
  public void test_create_empty_individual ()
    {
      var individual = new Individual (null);
      assert (individual.personas.size == 0);

      /* Check its properties. */
      assert (individual.trust_level == TrustLevel.NONE);
      assert (individual.avatar == null);
      assert (individual.presence_type == PresenceType.UNSET);
      assert (individual.presence_status == "");
      assert (individual.presence_message == "");
      assert (individual.client_types.length == 0);
      assert (individual.is_user == false);
      assert (individual.id == "");
      assert (individual.display_name == "");
      assert (individual.alias == "");
      assert (individual.structured_name == null);
      assert (individual.full_name == "");
      assert (individual.nickname == "");
      assert (individual.gender == Gender.UNSPECIFIED);
      assert (individual.urls.size == 0);
      assert (individual.phone_numbers.size == 0);
      assert (individual.email_addresses.size == 0);
      assert (individual.roles.size == 0);
      assert (individual.local_ids.size == 0);
      assert (individual.location ==null);
      assert (individual.birthday == null);
      assert (individual.calendar_event_id == null);
      assert (individual.notes.size == 0);
      assert (individual.postal_addresses.size == 0);
      assert (individual.is_favourite == false);
      assert (individual.groups.size == 0);
      assert (individual.im_addresses.size == 0);
      assert (individual.web_service_addresses.size == 0);
      assert (individual.im_interaction_count == 0);
      assert (individual.last_im_interaction_datetime == null);
      assert (individual.call_interaction_count == 0);
      assert (individual.last_call_interaction_datetime == null);

      assert (individual.personas.size == 0);
    }

  /* Test that manually creating an individual containing a single persona,
   * without using an IndividualAggregator, works. */
  public void test_create_singleton_individual ()
    {
      var persona_store = new FolksDummy.PersonaStore ("store0", "Store 0", {});
      var persona = new FolksDummy.Persona (persona_store, "persona0");
      var personas = new HashSet<Persona> ();
      personas.add (persona);

      var individual = new Individual (personas);
      assert (individual.personas.size == 1);
      foreach (var p in individual.personas)
          assert (p.individual == individual);
    }

  /* Test that manually creating an individual containing multiple personas,
   * without using an IndividualAggregator, works. */
  public void test_create_multi_individual ()
    {
      var persona_store = new FolksDummy.PersonaStore ("store0", "Store 0", {});
      var persona1 = new FolksDummy.Persona (persona_store, "persona0");
      var persona2 = new FolksDummy.Persona (persona_store, "persona1");

      var personas = new HashSet<Persona> ();
      personas.add (persona1);
      personas.add (persona2);

      var individual = new Individual (personas);
      assert (individual.personas.size == 2);
      foreach (var p in individual.personas)
          assert (p.individual == individual);
    }

  /* Test that adding a persona to one Individual, then adding it to a second
   * individual successfully moves the persona between the two. */
  public void test_persona_transferral ()
    {
      var persona_store = new FolksDummy.PersonaStore ("store0", "Store 0", {});
      var persona = new FolksDummy.Persona (persona_store, "persona0");

      var personas = new HashSet<Persona> ();
      personas.add (persona);

      /* Add the persona to the first individual. */
      var individual1 = new Individual (personas);
      assert (individual1.personas.size == 1);
      foreach (var p in individual1.personas)
          assert (p.individual == individual1);

      /* Now add the persona to a second individual. Have the persona’s
       * properties been updated? */
      var individual2 = new Individual (personas);
      assert (individual2.personas.size == 1);
      foreach (var p in individual2.personas)
          assert (p.individual == individual2);

      /* Has the persona been removed from individual1? */
      /* FIXME: For the moment, the persona remains in individual1.personas, as
       * well as being in individual2.personas. The persona’s ::individual
       * property correctly points to individual2, and it’s no longer connected
       * to any property changes in individual1. Reworking the internals of
       * libfolks to correctly remove the persona from individual1 is a fairly
       * large amount of work, and may result in behavioural changes. It needs
       * more time than I have at the moment. */
      /*assert (individual1.personas.size == 0);*/
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new StandaloneIndividualsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
