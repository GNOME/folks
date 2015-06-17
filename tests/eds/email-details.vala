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
 * Authors: Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *          Philip Withnall <philip.withnall@collabora.co.uk>
 *
 */

using EdsTest;
using Folks;
using Gee;

public class EmailDetailsTests : EdsTest.TestCase
{
  public EmailDetailsTests ()
    {
      base ("EmailDetails");

      this.add_test ("email details interface", this.test_email_details);
    }

  public void test_email_details ()
    {
      /* Set up the backend. */
      var c1 = new Gee.HashMap<string, Value?> ();
      var c2 = new Gee.HashMap<string, Value?> ();
      var c3 = new Gee.HashMap<string, Value?> ();
      Value? v;

      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      c1.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("bernie@example.org");
      c1.set (Edsf.Persona.email_fields[0], (owned) v);
      v = Value (typeof (string));
      v.set_string ("bernie.innocenti@example.org");
      c1.set (Edsf.Persona.email_fields[1], (owned) v);

      this.eds_backend.add_contact (c1);

      v = Value (typeof (string));
      v.set_string ("richard m. stallman");
      c2.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("rms@example.org");
      c2.set (Edsf.Persona.email_fields[0], (owned) v);
      v = Value (typeof (string));
      v.set_string ("rms.1@example.org");
      c2.set (Edsf.Persona.email_fields[1], (owned) v);

      this.eds_backend.add_contact (c2);

      v = Value (typeof (string));
      v.set_string ("foo bar");
      c3.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("foo@example.org");
      c3.set (Edsf.Persona.email_fields[0], (owned) v);
      v = Value (typeof (string));
      v.set_string ("foo.bar@example.org");
      c3.set (Edsf.Persona.email_fields[1], (owned) v);

      this.eds_backend.add_contact (c3);

      this.eds_backend.commit_contacts_to_addressbook_sync ();

      /* Set up the aggregator and wait until either the expected personas are
       * seen, or the test times out and fails. */
      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_individuals_sync_with_timeout (
          aggregator,
          {"bernie h. innocenti", "richard m. stallman", "foo bar"});

      /* Check the properties of our individuals. */
      var i1 = TestUtils.get_individual_by_name (aggregator,
          "bernie h. innocenti");
      this._check_email_details (i1, 2);

      var i2 = TestUtils.get_individual_by_name (aggregator,
          "richard m. stallman");
      this._check_email_details (i2, 2);

      var i3 = TestUtils.get_individual_by_name (aggregator,
          "foo bar");
      this._check_email_details (i3, 2);
    }

  private void _check_email_details (Individual i, uint n_expected)
    {
      var email_owner = (Folks.EmailDetails) i;

      foreach (var e in email_owner.email_addresses)
        {
          foreach (var v in e.get_parameter_values (AbstractFieldDetails.PARAM_TYPE))
              assert (v == AbstractFieldDetails.PARAM_TYPE_OTHER);
        }

      assert (email_owner.email_addresses.size == n_expected);
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new EmailDetailsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
