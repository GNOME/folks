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

using Gee;
using Folks;

public class UtilsTests : Folks.TestCase
{
  public UtilsTests ()
    {
      base ("Utils");
      this.add_test ("MultiMap equality", this.test_multi_map_equality);
    }

  public void test_multi_map_equality ()
    {
      var a_1 = new HashMultiMap<string, string> ();
      var a_2 = new HashMultiMap<string, string> ();
      var a_1_subset = new HashMultiMap<string, string> ();
      var b_1 = new HashMultiMap<string, string> ();

      a_1.set ("foo", "bar");
      a_1.set ("foo", "qux");
      a_1.set ("baz", "quux");

      a_2.set ("foo", "bar");
      a_2.set ("foo", "qux");
      a_2.set ("baz", "quux");

      a_1_subset.set ("foo", "bar");
      a_1_subset.set ("foo", "qux");

      b_1.set ("not", "at");
      b_1.set ("all", "related");

      assert (Utils.multi_map_str_str_equal (a_1, a_1));
      assert (Utils.multi_map_str_str_equal (a_1, a_2));
      assert (Utils.multi_map_str_str_equal (a_2, a_1));
      assert (!Utils.multi_map_str_str_equal (a_1, a_1_subset));
      assert (!Utils.multi_map_str_str_equal (a_1, b_1));
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new UtilsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
