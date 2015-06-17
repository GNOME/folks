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

public class ImDetailsTests : EdsTest.TestCase
{
  public ImDetailsTests ()
    {
      base ("ImDetailsTests");

      this.add_test ("test im details interface",
          this.test_im_details_interface);
    }

  public void test_im_details_interface ()
    {
      /* Set up the backend. */
      var c1 = new Gee.HashMap<string, Value?> ();
      var im_addrs = "im_jabber_home_1#test1@example.org";
      im_addrs += ",im_yahoo_home_1#test2@example.org";
      Value? v;

      v = Value (typeof (string));
      v.set_string ("persona #1");
      c1.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string (im_addrs);
      c1.set ("im_addresses", (owned) v);

      this.eds_backend.add_contact (c1);
      this.eds_backend.commit_contacts_to_addressbook_sync ();

      /* Set up the test variables. */
      var found_addr_1 = false;
      var found_addr_2 = false;

      /* Set up the aggregator and wait until either the expected personas are
       * seen, or the test times out and fails. */
      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_individuals_sync_with_timeout (
          aggregator, {"persona #1"});

      /* Check the properties of our individual. */
      var i = TestUtils.get_individual_by_name (aggregator, "persona #1");
      foreach (var proto in i.im_addresses.get_keys ())
        {
          var addrs = i.im_addresses.get (proto);

          if (proto == "jabber")
            {
              found_addr_1 =
                  addrs.contains (new ImFieldDetails ("test1@example.org"));
            }
          else if (proto == "yahoo")
            {
              found_addr_2 =
                  addrs.contains (new ImFieldDetails ("test2@example.org"));
            }
        }

      assert (found_addr_1);
      assert (found_addr_2);
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new ImDetailsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
