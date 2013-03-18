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

public class EmailFieldDetailsTests : Folks.TestCase
{
  public EmailFieldDetailsTests ()
    {
      base ("EmailFieldDetails");
      this.add_test ("parameter replacement", this.test_param_replacement);
      this.add_test ("simple equality", this.test_simple_equality);
      this.add_test ("parameter equality", this.test_params_equality);
      this.add_test ("ImFieldDetails equality",
          this.test_im_field_details_equality);
      this.add_test ("RoleFieldDetails equality",
          this.test_role_field_details_equality);
      this.add_test ("Generic AFD handling",
          this.test_generic_afd_handling);
    }

  public void test_param_replacement ()
    {
      string param_name = "metasyntactic-variables";
      string[] values_1 = {"foo", "bar", "baz"};
      string[] values_2 = {"qux", "quxx"};
      EmailFieldDetails details;
      Collection<string> values;

      details = new EmailFieldDetails (param_name);

      foreach (var val in values_1)
        details.add_parameter (param_name, val);

      /* populate with first list of param values */
      values = details.get_parameter_values (param_name);
      assert (values.size == values_1.length);
      foreach (var val in values_1)
        assert (values.contains (val));

      /* replace the list of param values */
      details.set_parameter (param_name, values_2[0]);
      values = details.get_parameter_values (param_name);
      assert (values.size == 1);
      assert (values.contains (values_2[0]));

      /* clear the list */
      details.remove_parameter_all (param_name);
      values = details.get_parameter_values (param_name);
      assert (values == null);

      /* populate with the combined list of values */
      foreach (var val in values_1)
        details.add_parameter (param_name, val);

      var values_2_list = new GLib.List<string> ();
      foreach (var val in values_2)
        values_2_list.append (val);

      var param_table = new HashMultiMap<string, string> ();
      foreach (var val in values_2_list)
        param_table.set (param_name, val);

      details.extend_parameters (param_table);
      values = details.get_parameter_values (param_name);
      assert (values.size == (values_1.length + values_2.length));
      foreach (var val in values_1)
        assert (values.contains (val));
      foreach (var val in values_2)
          assert (values.contains (val));
    }

  public void test_simple_equality ()
    {
      EmailFieldDetails details_a_1 = new EmailFieldDetails ("foo");
      EmailFieldDetails details_a_2 = new EmailFieldDetails ("foo");
      EmailFieldDetails details_b_1 = new EmailFieldDetails ("bar");

      /* Very-basic comparisons */
      assert (details_a_1.equal (details_a_2));
      assert (!details_a_1.equal (details_b_1));
      assert (!details_b_1.equal (details_a_1));
      assert (!details_b_1.equal (details_a_2));
    }

  public void test_params_equality ()
    {
      EmailFieldDetails details_a_1 = new EmailFieldDetails ("foo");
      EmailFieldDetails details_a_2 = new EmailFieldDetails ("foo");

      /* Add the parameters differently to the two instances to ensure these
       * methods work as expected */
      var parameters = new HashMultiMap<string, string> ();
      parameters.set ("bar", "baz");
      parameters.set ("qux", "quux");
      parameters.set ("qux", "quuux");
      details_a_1.parameters = parameters;

      foreach (var param in parameters.get_keys ())
        {
          var values = parameters[param];
          foreach (var value in values)
            details_a_2.add_parameter (param, value);
        }

      assert (details_a_1.equal (details_a_2));

      /* Add an existing value to a param for one object; shouldn't change */
      details_a_2.add_parameter ("bar", "baz");
      assert (details_a_1.equal (details_a_2));

      /* Add new value to param; ensure inequality */
      details_a_2.add_parameter ("bar", "new");
      assert (!details_a_1.equal (details_a_2));

      /* Re-set to original state */
      details_a_2.set_parameter ("bar", "baz");
      assert (details_a_1.equal (details_a_2));

      /* Add new value to param; ensure inequality */
      details_a_2.add_parameter ("bar", "new");
      assert (!details_a_1.equal (details_a_2));

      /* Re-set to original state (in a different way than above) */
      details_a_2.parameters.remove ("bar", "new");
      assert (details_a_1.equal (details_a_2));

      /* Remove parameter and values; ensure inequality */
      details_a_2.parameters.remove_all ("bar");
      assert (!details_a_1.equal (details_a_2));
    }

  public void test_im_field_details_equality ()
    {
      ImFieldDetails details_a_1 = new ImFieldDetails ("foo@example.org");
      ImFieldDetails details_a_2 = new ImFieldDetails ("foo@example.org");
      ImFieldDetails details_b_1 = new ImFieldDetails ("bar@other.example.org");

      /* Very-basic comparisons */
      assert (details_a_1.equal (details_a_2));
      assert (!details_a_1.equal (details_b_1));

      /* Comparing different derived classes */
      EmailFieldDetails details_c_1 = new EmailFieldDetails ("foo@example.org");
      assert (!details_a_1.equal (details_c_1));
    }

  public void test_role_field_details_equality ()
    {
      RoleFieldDetails details_a_1 = new RoleFieldDetails (
          new Role ("Captain", "Obvious Corp.", null));
      RoleFieldDetails details_a_2 = new RoleFieldDetails (
          new Role ("Captain", "Obvious Corp.", null));
      RoleFieldDetails details_b_1 = new RoleFieldDetails (
          new Role ("Flunkie", "Obvious Corp.", null));

      /* Very-basic comparisons */
      assert (details_a_1.equal (details_a_2));
      assert (!details_a_1.equal (details_b_1));
    }

  public void test_generic_afd_handling ()
    {
      AbstractFieldDetails afd;

      afd = new EmailFieldDetails ("foo@example.org");
      assert (afd.get_type ().is_a (typeof (AbstractFieldDetails)));
      assert (afd.value_type == typeof (string));

      afd = new ImFieldDetails ("bar@example.org");
      assert (afd.get_type ().is_a (typeof (AbstractFieldDetails)));
      assert (afd.value_type == typeof (string));

      afd = new NoteFieldDetails ("Are you writing this down?");
      assert (afd.get_type ().is_a (typeof (AbstractFieldDetails)));
      assert (afd.value_type == typeof (string));

      afd = new PhoneFieldDetails ("+19255551234");
      assert (afd.get_type ().is_a (typeof (AbstractFieldDetails)));
      assert (afd.value_type == typeof (string));

      afd = new PostalAddressFieldDetails (
          new PostalAddress (null, null, "123 Streetly Way", "Cityville",
            "Cascadia", null, "USA", null, null));
      assert (afd.get_type ().is_a (typeof (AbstractFieldDetails)));
      assert (afd.value_type == typeof (PostalAddress));
      assert (afd.value_type != typeof (string));

      afd = new RoleFieldDetails (
          new Role ("Captain", "Obvious Corp.", null));
      assert (afd.get_type ().is_a (typeof (AbstractFieldDetails)));
      assert (afd.value_type == typeof (Role));
      assert (afd.value_type != typeof (string));

      afd = new UrlFieldDetails ("http://other.side.of.nowhere");
      assert (afd.get_type ().is_a (typeof (AbstractFieldDetails)));
      assert (afd.value_type == typeof (string));

      afd = new WebServiceFieldDetails ("bluebomber");
      assert (afd.get_type ().is_a (typeof (AbstractFieldDetails)));
      assert (afd.value_type == typeof (string));
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new EmailFieldDetailsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
