using Gee;
using Folks;

public class LinkedHashSetTests : Folks.TestCase
{
  public LinkedHashSetTests ()
    {
      base ("LinkedHashSet");
      this.add_test ("set properties", this.test_set_properties);
      this.add_test ("list properties", this.test_list_properties);
      this.add_test ("object elements", this.test_object_elements);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_set_properties ()
    {
      /* XXX: ensure that values = values_no_dupes with some duplicates added */
      const int[] values = {5, 7, 7, 9};
      const int[] values_no_dupes = {5, 7, 9};
      LinkedHashSet<int> lhs;
      int i;

      /* some basic assumptions for our source data */
      assert (values_no_dupes.length < values.length);

      /*
       * Without duplicates
       */

      lhs = new LinkedHashSet<int> (direct_hash, direct_equal);
      assert (lhs.size == 0);

      foreach (var v1 in values_no_dupes)
        assert (lhs.add (v1));

      assert (lhs.size == values_no_dupes.length);

      for (i = 0; i < values_no_dupes.length; i++)
        assert (lhs.contains (values_no_dupes[i]));

      /*
       * Again, with dupes
       */

      lhs = new LinkedHashSet<int> (direct_hash, direct_equal);
      assert (lhs.size == 0);

      /* we can't assert this add will always return true, since there are
       * duplicates in the source array */
      foreach (var v2 in values)
        lhs.add (v2);

      /* since the lhs should ignore duplicates, it should be the size of the
       * unique array */
      assert (lhs.size == values_no_dupes.length);

      for (i = 0; i < values.length; i++)
        assert (lhs.contains (values[i]));

      for (i = 0; i < values_no_dupes.length; i++)
        assert (lhs.contains (values_no_dupes[i]));

      /* ensure we ignore duplicates */
      assert (!lhs.add (values_no_dupes[0]));
      assert (lhs.size == values_no_dupes.length);

      /* ensure proper return value when removing (successfully and not) */
      assert (lhs.remove (values_no_dupes[0]));
      assert (lhs.size == (values_no_dupes.length - 1));
      assert (!lhs.remove (values_no_dupes[0]));
      assert (lhs.size == (values_no_dupes.length - 1));
    }

  public void test_list_properties ()
    {
      /* XXX: ensure that values = values_no_dupes with some duplicates appended
       */
      const int[] values = {1, 3, 2, 3, 1, 2, 2};
      const int[] values_no_dupes = {1, 3, 2};
      int i;
      LinkedHashSet<int> lhs;

      lhs = new LinkedHashSet<int> (direct_hash, direct_equal);
      assert (lhs.size == 0);
      /* this item shouldn't exist, so we should get a negative return value */
      assert (lhs.index_of (1) < 0);

      /*
       * Without duplicates
       */
      foreach (var val in values_no_dupes)
        lhs.add (val);

      assert (lhs.first () == values_no_dupes[0]);
      assert (lhs.last () == values_no_dupes[values_no_dupes.length - 1]);

      i = 0;
      foreach (var val in lhs)
        {
          assert (i < values_no_dupes.length);
          assert (val == values_no_dupes[i]);
          i++;
        }

      /*
       * With duplicates
       */
      lhs = new LinkedHashSet<int> (direct_hash, direct_equal);
      assert (lhs.size == 0);
      /* this item shouldn't exist, so we should get a negative return value */
      assert (lhs.index_of (1) < 0);

      foreach (var val in values)
        lhs.add (val);

      /* check that lhs matches the content (and ordering of) values_no_dupes,
       * not values, since lhs will have ignored additional duplicates */
      assert (lhs.first () == values_no_dupes[0]);
      assert (lhs.last () == values_no_dupes[values_no_dupes.length - 1]);

      i = 0;
      foreach (var val in lhs)
        {
          assert (i < values_no_dupes.length);
          assert (val == values_no_dupes[i]);
          i++;
        }
    }

  private class Dummy : GLib.Object
    {
      public string name { get; construct; }

      public Dummy (string name)
        {
          Object (name: name);
        }

      public static uint hash_func (Dummy d)
        {
          return str_hash (d.name);
        }

      public static bool equal_func (Dummy d1, Dummy d2)
        {
          return str_equal (d1.name, d2.name);
        }
    }

  public void test_object_elements ()
    {
      /* XXX: ensure that values = values_no_dupes with some duplicates appended
       */
      string[] values = {"Mac", "Charlie", "Dennis", "Frank", "Charlie"};
      string[] values_no_dupes = {"Mac", "Charlie", "Dennis", "Frank"};
      int i;
      LinkedList<Dummy> ll;
      HashSet<Dummy> hs;
      LinkedHashSet<Dummy> lhs;

      /* FIXME: remove this cast once libgee catches up with Vala's delegate
       * definitions */
      ll = new LinkedList<Dummy> ((GLib.EqualFunc) Dummy.equal_func);
      hs = new HashSet<Dummy> ((GLib.HashFunc) Dummy.hash_func,
          (GLib.EqualFunc) Dummy.equal_func);
      lhs = new LinkedHashSet<Dummy> ((GLib.HashFunc) Dummy.hash_func,
          (GLib.EqualFunc) Dummy.equal_func);
      assert (lhs.size == 0);

      /*
       * Without duplicates
       */
      foreach (var val in values_no_dupes)
        {
          var dummy = new Dummy (val);
          ll.add (dummy);
          hs.add (dummy);
          lhs.add (dummy);
        }

      assert (lhs.first ().name == values_no_dupes[0]);
      assert (lhs.last ().name == values_no_dupes[values_no_dupes.length - 1]);

      foreach (var val in ll)
        assert (lhs.contains (val));

      foreach (var val in hs)
        assert (lhs.contains (val));

      i = 0;
      foreach (var val in ll)
        {
          assert (lhs.get (i).name == val.name);
          assert (lhs.index_of (val) == i);
          i++;
        }

      /*
       * With duplicates
       */
      /* FIXME: remove this cast once libgee catches up with Vala's delegate
       * definitions */
      ll = new LinkedList<Dummy> ((GLib.EqualFunc) Dummy.equal_func);
      hs = new HashSet<Dummy> ((GLib.HashFunc) Dummy.hash_func,
          (GLib.EqualFunc) Dummy.equal_func);
      lhs = new LinkedHashSet<Dummy> ((GLib.HashFunc) Dummy.hash_func,
          (GLib.EqualFunc) Dummy.equal_func);
      assert (lhs.size == 0);

      foreach (var val in values)
        {
          var dummy = new Dummy (val);
          ll.add (dummy);
          hs.add (dummy);
          lhs.add (dummy);
        }

      assert (lhs.first ().name == values_no_dupes[0]);
      assert (lhs.last ().name == values_no_dupes[values_no_dupes.length - 1]);

      foreach (var val in ll)
        assert (lhs.contains (val));

      foreach (var val in hs)
        assert (lhs.contains (val));

      i = 0;
      /* note that lhs and ll are swapped vs. the similar test without dupes */
      foreach (var val in lhs)
        {
          assert (ll.get (i).name == val.name);
          i++;
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new LinkedHashSetTests ().get_suite ());

  Test.run ();

  return 0;
}
