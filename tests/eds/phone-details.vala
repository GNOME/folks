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

public class PhoneDetailsTests : EdsTest.TestCase
{
  public PhoneDetailsTests ()
    {
      base ("PhoneDetails");

      this.add_test ("phone details interface", this.test_phone_numbers);
    }

  public void test_phone_numbers ()
    {
      /* Set up the backend. */
      var c1 = new Gee.HashMap<string, Value?> ();
      var c2 = new Gee.HashMap<string, Value?> ();
      Value? v;
      string[] names = {"bernie h. innocenti", "richard m. stallman"};

      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      c1.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("123");
      c1.set ("car_phone", (owned) v);
      v = Value (typeof (string));
      v.set_string ("1234");
      c1.set ("company_phone", (owned) v);
      v = Value (typeof (string));
      v.set_string ("12345");
      c1.set ("home_phone", (owned) v);

      this.eds_backend.add_contact (c1);

      v = Value (typeof (string));
      v.set_string ("richard m. stallman");
      c2.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("54321");
      c2.set ("car_phone", (owned) v);
      v = Value (typeof (string));
      v.set_string ("4321");
      c2.set ("company_phone", (owned) v);
      v = Value (typeof (string));
      v.set_string ("321");
      c2.set ("home_phone", (owned) v);

      this.eds_backend.add_contact (c2);

      this.eds_backend.commit_contacts_to_addressbook_sync ();

      /* Set up the test variables. */
      var phones_count = 0;
      var phone_types = new HashSet<string> ();

      /* Set up the aggregator and wait until either the expected personas are
       * seen, or the test times out and fails. */
      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_individuals_sync_with_timeout (
          aggregator, names);

      /* Check the properties of our individual. */
      foreach (var n in names)
        {
          var i = TestUtils.get_individual_by_name (aggregator, n);
          var contact = (n == "bernie h. innocenti") ? c1 : c2;

          contact.unset ("full_name");

          foreach (var phone_fd in i.phone_numbers)
            {
              phones_count++;
              foreach (var t in phone_fd.get_parameter_values (
                  AbstractFieldDetails.PARAM_TYPE))
                {
                  string? t_ = null;

                  if (t == "car")
                      t_ = "car_phone";
                  else if (t == AbstractFieldDetails.PARAM_TYPE_HOME)
                      t_ = "home_phone";
                  else if (t == "x-evolution-company")
                      t_ = "company_phone";
                  /* Expected aliases of the above: */
                  else if (t != "voice")
                    {
                      debug ("Unrecognised type: %s, %s", t, phone_fd.value);
                      assert_not_reached ();
                    }

                  if (t_ != null)
                    {
                      phone_types.add (t_);
                      assert (contact.get (t_).get_string () == phone_fd.value);
                      contact.unset (t_);
                    }
                }
            }
        }

      assert (phones_count == 6);
      assert (phone_types.size == 3);
      assert (c1.size == 0);
      assert (c2.size == 0);

      foreach (var pt in phone_types)
          assert (pt in Edsf.Persona.phone_fields);
   }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new PhoneDetailsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
