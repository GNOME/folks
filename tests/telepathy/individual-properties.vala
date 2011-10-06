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
  private HashSet<string> _changes_pending;

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
      this.add_test ("individual properties:change contact info",
          this.test_individual_properties_change_contact_info);

      if (Environment.get_variable ("FOLKS_TEST_VALGRIND") != null)
          this._test_timeout = 10;
    }

  public override void set_up ()
    {
      this.tp_backend.set_up ();
      this._account_handle = this.tp_backend.add_account ("protocol",
          "me@example.com", "cm", "account");
      this._changes_pending = new HashSet<string> ();
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
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          foreach (Individual i in added)
            {
              assert (i != null);

              /* Check the Individual containing just
               * Tpf.Persona(olivier@example.com) */
              if (i.id == "0e46c5e74f61908f49550d241f2a1651892a1695")
                {
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

                  /* Check writeability of fields */
                  Tpf.Persona tpf_persona = null;
                  foreach (var p in i.personas)
                    {
                      if (p is Tpf.Persona)
                        {
                          tpf_persona = p as Tpf.Persona;
                          break;
                        }
                    }
                  assert (tpf_persona != null);
                  assert ("alias" in tpf_persona.writeable_properties);
                  assert ("is-favourite" in tpf_persona.writeable_properties);
                  assert ("groups" in tpf_persona.writeable_properties);
                  /* These are only writeable for the user contact */
                  assert (!tpf_persona.is_user);
                  assert (!("full-name" in tpf_persona.writeable_properties));
                  assert (
                      !("phone-numbers" in tpf_persona.writeable_properties));

                  /* Check ContactInfo-provided properties */
                  assert (new PhoneFieldDetails ("+15142345678")
                      in i.phone_numbers);
                }
            }

          assert (removed.size == 1);

          foreach (var i in removed)
            {
              assert (i == null);
            }
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
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          var new_alias = "New Alias";

          foreach (Individual i in added)
            {
              assert (i != null);

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

          assert (removed.size == 1);

          foreach (var i in removed)
            {
              assert (i == null);
            }
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
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          var new_alias = "New Alias";

          foreach (Individual i in added)
            {
              assert (i != null);

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

          assert (removed.size == 1);

          foreach (var i in removed)
            {
              assert (i == null);
            }
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

  public void test_individual_properties_change_contact_info ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      this._changes_pending.add ("phone-numbers");
      this._changes_pending.add ("full-name");

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          this._change_contact_info_aggregator_individuals_added (changes);
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

      assert (this._changes_pending.size == 0);

      /* necessary to reset the aggregator for the next test */
      aggregator = null;
    }

  private async void _change_contact_info_aggregator_individuals_added (
      MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();
      var removed = changes.get_keys ();

      var new_phone_fd = new PhoneFieldDetails ("+112233445566");
      new_phone_fd.set_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_HOME);
      var new_full_name = "Cave Johnson";

      foreach (Individual i in added)
        {
          assert (i != null);

          /* Check properties */
          assert (new_full_name != i.full_name);
          assert (!(new_phone_fd in i.phone_numbers));

          i.notify["full-name"].connect ((s, p) =>
              {
                /* we can't re-use i here due to Vala's implementation */
                var ind = (Individual) s;

                if (ind.full_name == new_full_name)
                  this._changes_pending.remove ("full-name");
              });

          i.notify["phone-numbers"].connect ((s, p) =>
              {
                /* we can't re-use i here due to Vala's implementation */
                var ind = (Individual) s;

                if (new_phone_fd in ind.phone_numbers)
                  {
                    this._changes_pending.remove ("phone-numbers");
                  }
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

          var phones = new HashSet<PhoneFieldDetails> (
              (GLib.HashFunc) PhoneFieldDetails.hash,
              (GLib.EqualFunc) PhoneFieldDetails.equal);
          phones.add (new_phone_fd);

          /* set the extended info through Telepathy's ContactInfo interface and
           * wait for it to hit our notification callback above */

          /* setting the extended info on a non-user is invalid for the
           * Telepathy backend, so this tracks the number of expected errors for
           * intentionally-invalid property changes */
          int uncaught_errors = 0;

          if (!i.is_user)
            uncaught_errors++;
          try
            {
              yield ((Tpf.Persona) persona).change_full_name (new_full_name);
            }
          catch (PropertyError e1)
            {
              if (!i.is_user)
                uncaught_errors--;
            }

          if (!i.is_user)
            uncaught_errors++;
          try
            {
              yield ((Tpf.Persona) persona).change_phone_numbers (phones);
            }
          catch (PropertyError e2)
            {
              /* setting the extended info on a non-user is invalid for the
               * Telepathy backend */
              if (!i.is_user)
                uncaught_errors--;
            }

          if (!i.is_user)
            {
              assert (uncaught_errors == 0);
            }
        }

      assert (removed.size == 1);

      foreach (var r in removed)
        {
          assert (r == null);
        }
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
