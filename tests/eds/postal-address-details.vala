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

using Folks;
using Gee;

public class PostalAddressDetailsTests : EdsTest.TestCase
{
  public PostalAddressDetailsTests ()
    {
      base ("PostalAddressDetailsTests");

      this.add_test ("test postal address details interface",
          this.test_postal_address_details_interface);
    }

  public void test_postal_address_details_interface ()
    {
      /* Set up the backend. */
      var c1 = new Gee.HashMap<string, Value?> ();
      Value? v;

      var pobox = "12345";
      var locality = "example locality";
      var postalcode = "example postalcode";
      var street = "example street";
      var extended = "example extended address";
      var country = "example country";
      var region = "example region";

      v = Value (typeof (string));
      v.set_string ("persona #1");
      c1.set ("full_name", (owned) v);
      var pa_copy = new PostalAddress (
           pobox,
           extended,
           street,
           locality,
           region,
           postalcode,
           country,
           null, "eds_id");
      var pa_fd_copy = new PostalAddressFieldDetails (pa_copy);
      pa_fd_copy.add_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_HOME);
      v = Value (typeof (PostalAddressFieldDetails));
      v.set_object (pa_fd_copy);
      /* corresponds to address of type "home" */
      c1.set (Edsf.Persona.address_fields[0], (owned) v);

      this.eds_backend.add_contact (c1);
      this.eds_backend.commit_contacts_to_addressbook_sync ();

      /* Set up the aggregator and wait until either the expected personas are
       * seen, or the test times out and fails. */
      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_individuals_sync_with_timeout (
          aggregator, {"persona #1"});

      /* Check the properties of our individual. */
      var i = TestUtils.get_individual_by_name (aggregator, "persona #1");

      assert (i.postal_addresses.size == 1);

      var pa = new PostalAddress (
           pobox,
           extended,
           street,
           locality,
           region,
           postalcode,
           country,
           null, "eds_id");
      var postal_address = new PostalAddressFieldDetails (pa);
      postal_address.add_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_HOME);

      foreach (var pa_fd in i.postal_addresses)
        {
          /* We copy the uid - we don't know it.
           * Although we could get it from the 1st
           * personas iid; there is no real need.
           */
          postal_address.id = pa_fd.id;
          assert (pa_fd.equal (postal_address));
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new PostalAddressDetailsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
