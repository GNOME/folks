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

public class NameDetailsTests : EdsTest.TestCase
{
  public NameDetailsTests ()
    {
      base ("NameDetails");

      this.add_test ("name details interface", this.test_names);
    }

  public void test_names ()
    {
      /* Set up the backend. */
      var c1 = new Gee.HashMap<string, Value?> ();
      var c2 = new Gee.HashMap<string, Value?> ();
      Value? v;

      /* FIXME: passing the EContactName would be better */
      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      c1.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("bernie");
      c1.set ("nickname", (owned) v);
      v = Value (typeof (string));
      v.set_string ("Innocenti");
      c1.set ("contact_name_family", (owned) v);
      v = Value (typeof (string));
      v.set_string ("Bernardo");
      c1.set ("contact_name_given", (owned) v);
      v = Value (typeof (string));
      v.set_string ("H.");
      c1.set ("contact_name_additional", (owned) v);
      v = Value (typeof (string));
      v.set_string ("Mr.");
      c1.set ("contact_name_prefixes", (owned) v);
      v = Value (typeof (string));
      v.set_string ("(sysadmin FSF)");
      c1.set ("contact_name_suffixes", (owned) v);

      this.eds_backend.add_contact (c1);

      v = Value (typeof (string));
      v.set_string ("richard m. stallman");
      c2.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("Stallman");
      c2.set ("contact_name_family", (owned) v);
      v = Value (typeof (string));
      v.set_string ("Richard M.");
      c2.set ("contact_name_given", (owned) v);

      this.eds_backend.add_contact (c2);

      this.eds_backend.commit_contacts_to_addressbook_sync ();

      /* Set up the aggregator and wait until either the expected personas are
       * seen, or the test times out and fails. */
      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_individuals_sync_with_timeout (
          aggregator, {"bernie h. innocenti", "richard m. stallman"});

      /* Check the properties of our individuals. */
      string s;

      var i1 = TestUtils.get_individual_by_name (aggregator,
          "bernie h. innocenti");
      var name1 = (Folks.NameDetails) i1;

      assert (name1.structured_name.is_empty () == false);

      s = c1.get ("full_name").get_string ();
      assert (name1.full_name == s);
      c1.unset ("full_name");

      s = c1.get ("nickname").get_string ();
      assert (name1.nickname == s);
      c1.unset ("nickname");

      s = c1.get ("contact_name_family").get_string ();
      assert (name1.structured_name.family_name == s);
      c1.unset ("contact_name_family");

      s = c1.get ("contact_name_given").get_string ();
      assert (name1.structured_name.given_name == s);
      c1.unset ("contact_name_given");

      s = c1.get ("contact_name_additional").get_string ();
      assert (name1.structured_name.additional_names == s);
      c1.unset ("contact_name_additional");

      s = c1.get ("contact_name_prefixes").get_string ();
      assert (name1.structured_name.prefixes == s);
      c1.unset ("contact_name_prefixes");

      s = c1.get ("contact_name_suffixes").get_string ();
      assert (name1.structured_name.suffixes == s);
      c1.unset ("contact_name_suffixes");

      assert (c1.size == 0);

      var i2 = TestUtils.get_individual_by_name (aggregator,
          "richard m. stallman");
      var name2 = (Folks.NameDetails) i2;

      assert (name2.structured_name.is_empty () == false);

      s = c2.get ("full_name").get_string ();
      assert (name2.full_name == s);
      c2.unset ("full_name");

      s = c2.get ("contact_name_family").get_string ();
      assert (name2.structured_name.family_name == s);
      c2.unset ("contact_name_family");

      s = c2.get ("contact_name_given").get_string ();
      assert (name2.structured_name.given_name == s);
      c2.unset ("contact_name_given");

      assert (c2.size == 0);
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new NameDetailsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
