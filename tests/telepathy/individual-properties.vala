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

public class IndividualPropertiesTests : TpfTest.TestCase
{
  private HashSet<string>? _changes_pending = null;

  private static string iid_prefix =
      "telepathy:/org/freedesktop/Telepathy/Account/cm/protocol/account:";
  private string olivier_sha1 = Checksum.compute_for_string (ChecksumType.SHA1,
      iid_prefix + "olivier@example.com");

  public IndividualPropertiesTests ()
    {
      base ("IndividualProperties");

      this.add_test ("individual properties",
          this.test_individual_properties);
      this.add_test ("individual properties:change alias through tp backend",
          this.test_individual_properties_change_alias_through_tp_backend);
      this.add_test ("individual properties:change alias through test cm",
          this.test_individual_properties_change_alias_through_test_cm);
      this.add_test ("individual properties:change contact info",
          this.test_individual_properties_change_contact_info);
    }

  public override void set_up ()
    {
      base.set_up ();

      this._changes_pending = new HashSet<string> ();
    }

  public override void tear_down ()
    {
      this._changes_pending = null;

      base.tear_down ();
    }

  public void test_individual_properties ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          foreach (Individual i in added)
            {
              assert (i != null);

              /* Check the user Individual */
              if (i.is_user)
                {
                  /* Check properties */
                  assert (i.alias == "me@example.com");
                  assert (i.presence_message == "");
                  assert (i.presence_status == "available");
                  assert (i.presence_type == PresenceType.AVAILABLE);
                  assert (((PresenceDetails) i).is_online () == true);

                  /* Check groups */
                  assert (i.groups.size == 0);

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
                  /* The logger isn't run in the test suite. */
                  assert (!("is-favourite"
                       in tpf_persona.writeable_properties));
                  assert ("groups" in tpf_persona.writeable_properties);
                  /* These are only writeable for the user contact */
                  assert (tpf_persona.is_user);
                  assert ("birthday" in tpf_persona.writeable_properties);
                  assert (
                      "email-addresses" in tpf_persona.writeable_properties);
                  assert (("full-name" in tpf_persona.writeable_properties));
                  assert (
                      ("phone-numbers" in tpf_persona.writeable_properties));
                  assert ("urls" in tpf_persona.writeable_properties);

                  /* Check ContactInfo-provided properties */
                  assert (i.full_name == "");
                  assert (i.phone_numbers.size == 0);
                }

              /* Check the Individual containing just
               * Tpf.Persona(olivier@example.com) */
              else if (i.id == olivier_sha1)
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
                  /* The logger isn't run in the test suite. */
                  assert (!("is-favourite"
                      in tpf_persona.writeable_properties));
                  assert ("groups" in tpf_persona.writeable_properties);
                  /* These are only writeable for the user contact */
                  assert (!tpf_persona.is_user);
                  assert (!("birthday" in tpf_persona.writeable_properties));
                  assert (
                      !("email-addresses" in tpf_persona.writeable_properties));
                  assert (!("full-name" in tpf_persona.writeable_properties));
                  assert (
                      !("phone-numbers" in tpf_persona.writeable_properties));
                  assert (!("urls" in tpf_persona.writeable_properties));

                  /* Check ContactInfo-provided properties */
                  assert (new PhoneFieldDetails ("+15142345678")
                      in i.phone_numbers);
                  assert (i.full_name == "Olivier Crete");
                  assert (new EmailFieldDetails ("olivier@example.com")
                      in i.email_addresses);
                  assert (new UrlFieldDetails ("ocrete.example.com") in i.urls);
                }
            }

          assert (removed.size == 1);

          foreach (var i in removed)
            {
              assert (i == null);
            }
        });
      aggregator.prepare.begin ();

      /* Kill the main loop after a few seconds. If there are still individuals
       * in the set of expected individuals, the aggregator has either failed
       * or been too slow (which we can consider to be failure). */
      TestUtils.loop_run_with_timeout (main_loop);

      /* necessary to reset the aggregator for the next test */
      aggregator = null;
    }

  public void test_individual_properties_change_alias_through_tp_backend ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var alias_notified = false;

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
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
              if (i.id != olivier_sha1)
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
      aggregator.prepare.begin ();

      /* Kill the main loop after a few seconds. If the alias hasn't been
       * notified, something along the way failed or been too slow (which we can
       * consider to be failure). */
      TestUtils.loop_run_with_timeout (main_loop);

      assert (alias_notified);

      /* necessary to reset the aggregator for the next test */
      aggregator = null;
    }

  public void test_individual_properties_change_alias_through_test_cm ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var alias_notified = false;

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
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
              if (i.id != olivier_sha1)
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
              var conn = this.tp_backend.get_connection_for_handle (this.account_handle);
              conn.change_aliases ({handle}, {new_alias});
            }

          assert (removed.size == 1);

          foreach (var i in removed)
            {
              assert (i == null);
            }
        });
      aggregator.prepare.begin ();

      /* Kill the main loop after a few seconds. If the alias hasn't been
       * notified, something along the way failed or been too slow (which we can
       * consider to be failure). */
      TestUtils.loop_run_with_timeout (main_loop);

      assert (alias_notified);

      /* necessary to reset the aggregator for the next test */
      aggregator = null;
    }

  public void test_individual_properties_change_contact_info ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      this._changes_pending.add ("birthday");
      this._changes_pending.add ("email-addresses");
      this._changes_pending.add ("phone-numbers");
      this._changes_pending.add ("full-name");
      this._changes_pending.add ("urls");

      /* Set up the aggregator */
      var aggregator = IndividualAggregator.dup ();
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          this._change_contact_info_aggregator_individuals_added.begin (changes);
        });

      aggregator.prepare.begin ();

      /* Kill the main loop after a few seconds. If the alias hasn't been
       * notified, something along the way failed or been too slow (which we can
       * consider to be failure). */
      TestUtils.loop_run_with_timeout (main_loop);

      assert (this._changes_pending.size == 0);

      /* necessary to reset the aggregator for the next test */
      aggregator = null;
    }

  private async void _change_contact_info_aggregator_individuals_added (
      MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();
      var removed = changes.get_keys ();

      var timeval = TimeVal ();
      timeval.from_iso8601 ("1929-01-11T00:00:00Z");
      var new_birthday = new DateTime.from_timeval_utc (timeval);
      assert (new_birthday != null);
      var new_email_fd = new EmailFieldDetails ("cave@aperturescience.com");
      new_email_fd.set_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_WORK);
      var new_phone_fd = new PhoneFieldDetails ("+112233445566");
      new_phone_fd.set_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_HOME);
      var new_url_fd = new UrlFieldDetails ("aperturescience.com/cave");
      new_url_fd.set_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_WORK);
      var new_full_name = "Cave Johnson";

      foreach (Individual i in added)
        {
          assert (i != null);

          /* Check properties */
          assert (i.birthday == null || !new_birthday.equal (i.birthday));
          assert (!(new_email_fd in i.email_addresses));
          assert (new_full_name != i.full_name);
          assert (!(new_phone_fd in i.phone_numbers));
          assert (!(new_url_fd in i.urls));

          i.notify["birthday"].connect ((s, p) =>
              {
                /* we can't re-use i here due to Vala's implementation */
                var ind = (Individual) s;

                if (ind.birthday != null && new_birthday != null &&
                  ind.birthday.equal (new_birthday))
                  {
                    this._changes_pending.remove ("birthday");
                  }
              });

          i.notify["email-addresses"].connect ((s, p) =>
              {
                /* we can't re-use i here due to Vala's implementation */
                var ind = (Individual) s;

                if (new_email_fd in ind.email_addresses)
                  {
                    this._changes_pending.remove ("email-addresses");
                  }
              });

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

          i.notify["urls"].connect ((s, p) =>
              {
                /* we can't re-use i here due to Vala's implementation */
                var ind = (Individual) s;

                if (new_url_fd in ind.urls)
                  {
                    this._changes_pending.remove ("urls");
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

          var emails = new HashSet<EmailFieldDetails> (
              AbstractFieldDetails<string>.hash_static,
              AbstractFieldDetails<string>.equal_static);
          emails.add (new_email_fd);
          var phones = new HashSet<PhoneFieldDetails> (
              AbstractFieldDetails<string>.hash_static,
              AbstractFieldDetails<string>.equal_static);
          phones.add (new_phone_fd);
          var urls = new HashSet<UrlFieldDetails> (
              AbstractFieldDetails<string>.hash_static,
              AbstractFieldDetails<string>.equal_static);
          urls.add (new_url_fd);

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
              yield ((Tpf.Persona) persona).change_birthday (new_birthday);
            }
          catch (PropertyError e_birthday)
            {
              if (!i.is_user)
                uncaught_errors--;
            }

          if (!i.is_user)
            uncaught_errors++;
          try
            {
              yield ((Tpf.Persona) persona).change_email_addresses (emails);
            }
          catch (PropertyError e0)
            {
              /* setting the extended info on a non-user is invalid for the
               * Telepathy backend */
              if (!i.is_user)
                uncaught_errors--;
            }

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
            uncaught_errors++;
          try
            {
              yield ((Tpf.Persona) persona).change_urls (urls);
            }
          catch (PropertyError e3)
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

  var tests = new IndividualPropertiesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
