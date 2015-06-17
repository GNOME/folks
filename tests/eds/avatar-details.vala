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

public class AvatarDetailsTests : EdsTest.TestCase
{
  public AvatarDetailsTests ()
    {
      base ("AvatarDetails");

      this.add_test ("avatar details interface", this.test_avatar);
    }

  public void test_avatar ()
    {
      /* Set up the backend. */
      var c1 = new Gee.HashMap<string, Value?> ();
      var avatar_path =
          Folks.TestUtils.get_source_test_data ("data/avatar-01.jpg");
      Value? v;

      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      c1.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string (avatar_path);
      c1.set ("avatar", (owned) v);

      this.eds_backend.add_contact (c1);
      this.eds_backend.commit_contacts_to_addressbook_sync ();

      /* Set up the test variables. */
      var avatars_are_equal = false;

      /* Set up the aggregator and wait until either the expected personas are
       * seen, or the test times out and fails. */
      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_individuals_sync_with_timeout (
          aggregator, {"bernie h. innocenti"});

      /* Check the properties of our individual. */
      var i = TestUtils.get_individual_by_name (aggregator,
          "bernie h. innocenti");
      if (i.avatar != null)
        {
          var b = new FileIcon (File.new_for_path (avatar_path));

          var main_loop = new MainLoop ();
          TestUtils.loadable_icons_content_equal.begin (i.avatar, b, -1,
              (s, r) =>
            {
              avatars_are_equal =
                  TestUtils.loadable_icons_content_equal.end (r);
              main_loop.quit ();
            });

          TestUtils.loop_run_with_timeout (main_loop);
        }

      assert (avatars_are_equal);
   }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new AvatarDetailsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
