/*
 * Copyright (C) 2014 Renato Araujo Oliveira Filho
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
 * Authors: Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *          Travis Reitter <travis.reitter@collabora.co.uk>
 *          Renato Araujo Oliveira Filho <renato@canonical.com>
 *
 */

using Folks;
using Gee;

public class LinkablePropertiesTests : DummyTest.TestCase
{
  private IndividualAggregator _aggregator;
  private GLib.MainLoop _main_loop;
  private bool _found_before_update;
  private bool _found_after_update;

  /* NOTE: each full name must remain unique. Likewise for email. */
  private const string _full_name_1 = "bernie h. innocenti";
  private const string _email_1 = "bernie@example.org";
  private const string _phone_1 = "5551234";
  private const string _full_name_2 = "Clyde McPoyle";
  private const string _email_2 = "clyde@example.org";
  private const string _phone_2 = "987654321";
  private Individual _ind_1;
  private Individual _ind_2;

  /* In general, these tests are meant to check basic behavior so we don't need
   * to sprinkle that throughout (and potentially revise) within unrelated tests
   */
  public LinkablePropertiesTests ()
    {
      base ("LinkableProperties");

      this.add_test ("correct aggregation after linkable property change",
          this.test_linkable_properties_aggregate_after_change);
    }

  public override void set_up ()
    {
      base.set_up ();

      this._found_before_update = false;
      this._found_after_update = false;
    }

  public override void configure_primary_store ()
    {
       base.configure_primary_store ();
       this.dummy_persona_store.update_trust_level (PersonaStoreTrust.FULL);
    }

  private async void _add_persona (owned Gee.HashMap<string, Value?> c)
    {
      HashTable<string, Value?> details = new HashTable<string, Value?>
          (str_hash, str_equal);

      Value? v1 = Value (typeof (string));
      v1.set_string (c["full_name"].get_string());
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.FULL_NAME),
          (owned) v1);

      Value? v2 = Value (typeof (Set));
      var emails = new HashSet<EmailFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);
      var email_1 = new EmailFieldDetails (c["email_1"].get_string());
      email_1.set_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_HOME);
      emails.add (email_1);
      v2.set_object (emails);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES),
          (owned) v2);

      Value? v5 = Value (typeof (Set));
      var phones = new HashSet<PhoneFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

      var phone_1 = new PhoneFieldDetails (c["home_phone"].get_string());
      phone_1.set_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_HOME);
      phones.add (phone_1);
      v5.set_object (phones);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.PHONE_NUMBERS),
          (owned) v5);

      try
        {
          yield this._aggregator.add_persona_from_details (null,
              this.dummy_persona_store, details);
        }
      catch (Folks.IndividualAggregatorError e)
        {
          GLib.warning ("[AddPersonaError] add_persona_from_details: %s\n",
              e.message);
        }
    }


  /* Check that two unaggregated Personas get aggregated after one changes its
   * linkable property to match the other's (ie, they get linked)
   */
  private async void _add_personas ()
    {
      Gee.HashMap<string, Value?> c;
      Value? v;

      this._found_before_update = false;
      this._found_after_update = false;

      c = new Gee.HashMap<string, Value?> ();
      v = Value (typeof (string));
      v.set_string (_full_name_1);
      c.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string (_email_1);
      c.set ("email_1", (owned) v);
      v = Value (typeof (string));
      v.set_string (_phone_1);
      c.set ("home_phone", (owned) v);
      yield this._add_persona (c);

      c = new Gee.HashMap<string, Value?> ();
      v = Value (typeof (string));
      v.set_string (_full_name_2);
      c.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string (_email_2);
      c.set ("email_1", (owned) v);
      v = Value (typeof (string));
      v.set_string (_phone_2);
      c.set ("home_phone", (owned) v);
      yield this._add_persona (c);
    }

  private void test_linkable_properties_aggregate_after_change ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      test_linkable_properties_aggregate_after_change_continue.begin ();
      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_before_update);
      assert (this._found_after_update);
    }

  private async void test_linkable_properties_aggregate_after_change_continue ()
    {
      this._aggregator = IndividualAggregator.dup ();
      this._aggregator.individuals_changed_detailed.connect (this._individuals_changed_aggregate_after_change_cb);
      try
        {
          yield this._aggregator.prepare ();
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }

      yield this._add_personas ();
    }

  private void _individuals_changed_aggregate_after_change_cb (
       MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();

      if (!this._found_before_update)
        {
          foreach (Individual i in added)
            {
              assert (i != null);

              var name = (Folks.NameDetails) i;

              if (name.full_name == _full_name_1)
                {
                  this._ind_1 = i;
                }
              /* Change the second Persona's email address to match the first so
               * they should get aggregated */
              else if (name.full_name == _full_name_2)
                {
                  this._ind_2 = i;
                  this._found_before_update = true;

                  foreach (var p in i.personas)
                    {
                      var emails = new HashSet<EmailFieldDetails> (
                          AbstractFieldDetails<string>.hash_static,
                          AbstractFieldDetails<string>.equal_static);
                      var email_1 = new EmailFieldDetails (_email_1);
                      email_1.set_parameter (AbstractFieldDetails.PARAM_TYPE,
                          AbstractFieldDetails.PARAM_TYPE_OTHER);
                      emails.add (email_1);
                      ((EmailDetails) p).email_addresses = emails;
                    }
                }
            }
        }
      else
        {
          Individual replaced;

          if (changes.contains (this._ind_1))
            {
              replaced = this._ind_1;
            }
          else if (changes.contains (this._ind_2))
            {
              replaced = this._ind_2;
            }
          else
            {
              return;
            }

          var replacements = changes.get (replaced);
          foreach (var r in replacements)
            {
              var phone_fd_1 = new PhoneFieldDetails (_phone_1);
              var phone_fd_2 = new PhoneFieldDetails (_phone_1);
              var num_equal_1 = false;
              var num_equal_2 = false;

              if (r.personas.size == 2)
                {
                  foreach (var num in r.phone_numbers)
                    {
                      if (num.values_equal (phone_fd_1))
                        num_equal_1 = true;

                      if (num.values_equal (phone_fd_2))
                        num_equal_2 = true;
                    }

                  if (num_equal_1 && num_equal_2)
                    {
                      this._found_after_update = true;
                      this._main_loop.quit ();
                    }
                }
            }
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new LinkablePropertiesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
