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
using TpTest;
using Tpf;
using Folks;
using Gee;

public class IndividualPropertiesTests : Folks.TestCase
{
  private TpTest.Backend tp_backend;
  private void* _account_handle;
  private int _test_timeout = 3;

  public IndividualPropertiesTests ()
    {
      base ("IndividualProperties");

      this.tp_backend = new TpTest.Backend ();

      this.add_test ("individual properties",
          this.test_individual_properties);
      this.add_test ("individual properties:change alias through tp backend",
          this.test_individual_properties_change_alias_through_tp_backend);
      this.add_test ("individual properties:change alias through test cm",
          this.test_individual_properties_change_alias_through_test_cm);

      if (Environment.get_variable ("FOLKS_TEST_VALGRIND") != null)
          this._test_timeout = 10;
    }

  public override void set_up ()
    {
      this.tp_backend.set_up ();
      this._account_handle = this.tp_backend.add_account ("protocol",
          "me@example.com", "cm", "account");
    }

  public override void tear_down ()
    {
      this.tp_backend.remove_account (this._account_handle);
      this.tp_backend.tear_down ();
    }

  public void test_individual_properties ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          foreach (Individual i in added)
            {
              /* We only check one (singleton Individual containing just
               * olivier@example.com) */
              if (i.id != "0e46c5e74f61908f49550d241f2a1651892a1695")
                {
                  continue;
                }

              /* Check properties */
              assert (i.alias == "Olivier");
              assert (i.presence_message == "");
              assert (i.presence_status == "away");
              assert (i.presence_type == PresenceType.AWAY);
              assert (((PresenceDetails) i).is_online () == true);

              /* Check groups */
              assert (i.groups.size == 2);
              assert (i.groups.contains ("Montreal") == true);
              assert (i.groups.contains ("Francophones") == true);
            }

          assert (removed.size == 0);
        });
      aggregator.prepare ();

      /* Kill the main loop after a few seconds. If there are still individuals
       * in the set of expected individuals, the aggregator has either failed
       * or been too slow (which we can consider to be failure). */
      Timeout.add_seconds (this._test_timeout, () =>
        {
          main_loop.quit ();
          return false;
        });

      main_loop.run ();

      /* necessary to reset the aggregator for the next test */
      aggregator = null;
    }

  public void test_individual_properties_change_alias_through_tp_backend ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var alias_notified = false;

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          var new_alias = "New Alias";

          foreach (Individual i in added)
            {
              /* We only check one (singleton Individual containing just
               * olivier@example.com) */
              if (i.id != "0e46c5e74f61908f49550d241f2a1651892a1695")
                {
                  continue;
                }

              /* Check properties */
              assert (i.alias != new_alias);

              i.notify["alias"].connect ((s, p) =>
                  {
                    /* we can't re-use i here due to Vala's implementation */
                    var ind = (Individual) s;

                    if (ind.alias == new_alias)
                      alias_notified = true;
                  });

              /* the contact list this aggregator is based upon has exactly 1
               * Tpf.Persona per Individual */
              Folks.Persona persona = null;
              foreach (var p in i.personas)
                {
                  persona = p;
                  break;
                }
              assert (persona is Tpf.Persona);

              /* set the alias through Telepathy and wait for it to hit our
               * alias notification callback above */

              ((Tpf.Persona) persona).alias = new_alias;
            }

          assert (removed.size == 0);
        });
      aggregator.prepare ();

      /* Kill the main loop after a few seconds. If the alias hasn't been
       * notified, something along the way failed or been too slow (which we can
       * consider to be failure). */
      Timeout.add_seconds (this._test_timeout, () =>
        {
          main_loop.quit ();
          return false;
        });

      main_loop.run ();

      assert (alias_notified);

      /* necessary to reset the aggregator for the next test */
      aggregator = null;
    }

  public void test_individual_properties_change_alias_through_test_cm ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var alias_notified = false;

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          var new_alias = "New Alias";

          foreach (Individual i in added)
            {
              /* We only check one (singleton Individual containing just
               * olivier@example.com) */
              if (i.id != "0e46c5e74f61908f49550d241f2a1651892a1695")
                {
                  continue;
                }

              /* Check properties */
              assert (i.alias != new_alias);

              i.notify["alias"].connect ((s, p) =>
                  {
                    /* we can't re-use i here due to Vala's implementation */
                    var ind = (Individual) s;

                    if (ind.alias == new_alias)
                      alias_notified = true;
                  });

              /* the contact list this aggregator is based upon has exactly 1
               * Tpf.Persona per Individual */
              Folks.Persona persona = null;
              foreach (var p in i.personas)
                {
                  persona = p;
                  break;
                }
              assert (persona is Tpf.Persona);

              /* set the alias through Telepathy and wait for it to hit our
               * alias notification callback above */

              var handle = (Handle) ((Tpf.Persona) persona).contact.handle;
              this.tp_backend.connection.manager.set_alias (handle, new_alias);
            }

          assert (removed.size == 0);
        });
      aggregator.prepare ();

      /* Kill the main loop after a few seconds. If the alias hasn't been
       * notified, something along the way failed or been too slow (which we can
       * consider to be failure). */
      Timeout.add_seconds (this._test_timeout, () =>
        {
          main_loop.quit ();
          return false;
        });

      main_loop.run ();

      assert (alias_notified);

      /* necessary to reset the aggregator for the next test */
      aggregator = null;
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new IndividualPropertiesTests ().get_suite ());

  Test.run ();

  return 0;
}
