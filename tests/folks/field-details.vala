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
      uint i;
      unowned GLib.List<string> values;

      details = new FieldDetails (param_name);

      foreach (var val in values_1)
        details.add_parameter (param_name, val);

      /* populate with first list of param values */
      i = 0;
      values = details.get_parameter_values (param_name);
      assert (values.length () == values_1.length);
      for (unowned List<string> l = values; l != null; l = l.next, i++)
        assert (l.data == values_1[i]);

      /* replace the list of param values */
      i = 0;
      details.set_parameter (param_name, values_2[0]);
      values = details.get_parameter_values (param_name);
      assert (values.length () == 1);
      for (unowned List<string> l = values; l != null; l = l.next, i++)
          assert (l.data == values_2[i]);

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

      var param_table = new HashTable<string, unowned List<string>> (str_hash,
          str_equal);
      param_table.insert (param_name, values_2_list);

      details.extend_parameters (param_table);
      values = details.get_parameter_values (param_name);
      assert (values.length () == (values_1.length + values_2.length));
      i = 0;
      for (; i < values_1.length; i++)
        assert (values.nth_data (i) == values_1[i]);
      for (; i < values_2.length; i++)
        assert (values.nth_data (i) == values_2[i]);
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
