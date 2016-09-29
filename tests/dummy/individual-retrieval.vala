/*
 * Copyright (C) 2011, 2013 Collabora Ltd.
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
 * Authors: Renato Araujo Oliveira Filho <renato@canonical.com>
 *          Philip Withnall <philip.withnall@collabora.co.uk>
 */

using Gee;
using Folks;
using DummyTest;
using FolksDummy;

public class IndividualRetrievalTests : DummyTest.TestCase
{
  public IndividualRetrievalTests ()
    {
      base ("IndividualRetrieval");

      this.add_test ("dummy individuals", this.test_aggregator);
    }

  private struct PersonaInfo
    {
      unowned string contact_id;
      unowned string full_name;
      unowned string nickname;
      unowned string home_email_address;
      unowned string jabber_im_address;
      unowned string yahoo_im_address;
    }

  private const PersonaInfo[] _persona_info =
    {
      { "dummy@2", "Rodrigo A", "kiko", "rodrigo@gmail.com",
          "rodrigo@jabber.com", "rodrigo@yahoo.com" },
      { "dummy@1", "Renato F", "renatof", "renato@gmail.com",
          "renato@jabber.com", "renato@yahoo.com" },
    };

  private static async FolksDummy.Persona _create_persona_from_info (
      FolksDummy.PersonaStore store, PersonaInfo info)
    {
      var p = new FullPersona (store, info.contact_id);

      try
        {
          /* Names. */
          yield p.change_full_name (info.full_name);
          yield p.change_nickname (info.nickname);

          /* E-mail addresses. */
          var emails = new HashSet<EmailFieldDetails> (
              AbstractFieldDetails<string>.hash_static,
              AbstractFieldDetails<string>.equal_static);

          var email_1 = new EmailFieldDetails (info.home_email_address);
          email_1.set_parameter (AbstractFieldDetails.PARAM_TYPE,
              AbstractFieldDetails.PARAM_TYPE_HOME);
          emails.add (email_1);

          yield p.change_email_addresses (emails);

          /* IM addresses. */
          var im_fds = new HashMultiMap<string, ImFieldDetails> ();
          im_fds.set ("jabber", new ImFieldDetails (info.jabber_im_address));
          im_fds.set ("yahoo", new ImFieldDetails (info.yahoo_im_address));

          yield p.change_im_addresses (im_fds);
        }
      catch (Folks.PropertyError e)
        {
          error ("Error setting property: %s", e.message);
        }

      return p;
    }

  private async void _register_personas ()
    {
      var personas = new HashSet<FolksDummy.Persona> ();

      /* Create a set of personas. */
      foreach (var info in IndividualRetrievalTests._persona_info)
        {
          var p =
              yield IndividualRetrievalTests._create_persona_from_info (
                  this.dummy_persona_store, info);
          personas.add (p);
        }

      /* Register them with the dummy store. */
      this.dummy_persona_store.register_personas (personas);
    }

  public void test_aggregator ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      HashSet<string> expected_individuals = new HashSet<string> ();
      expected_individuals.add ("Renato F");
      expected_individuals.add ("Rodrigo A");

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
      ulong handler_id = aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          assert (added.size == 2);

          foreach (Individual i in added)
            {
              assert (i != null);
              expected_individuals.remove (i.full_name);
            }

          assert (removed.size == 1);

          main_loop.quit ();
        });

      /* Prepare the aggregator, then instruct the store to reach quiescence,
       * then register the personas with the store. This should result in an
       * individuals-changed signal. */
      aggregator.prepare.begin ((s, r) =>
        {
          try
            {
              aggregator.prepare.end (r);

              this.dummy_persona_store.reach_quiescence ();

              this._register_personas.begin ((s, r) =>
                {
                  this._register_personas.end (r);
                });
            }
          catch (GLib.Error e1)
            {
              error ("Failed to prepare aggregator: %s", e1.message);
            }
        });

      /* Run the test for a few seconds and fail if the timeout is exceeded. */
      TestUtils.loop_run_with_timeout (main_loop);

      /* We should have enumerated exactly the individuals in the set */
      assert (expected_individuals.size == 0);
      aggregator.disconnect(handler_id);
      aggregator = null;
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
