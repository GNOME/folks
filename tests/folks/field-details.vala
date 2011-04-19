using Gee;
using Folks;

public class FieldDetailsTests : Folks.TestCase
{
  public FieldDetailsTests ()
    {
      base ("FieldDetails");
      this.add_test ("parameter replacement", this.test_param_replacement);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_param_replacement ()
    {
      string param_name = "metasyntactic-variables";
      string[] values_1 = {"foo", "bar", "baz"};
      string[] values_2 = {"qux", "quxx"};
      FieldDetails details;
      Collection<string> values;

      details = new FieldDetails (param_name);

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
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new FieldDetailsTests ().get_suite ());

  Test.run ();

  return 0;
}
