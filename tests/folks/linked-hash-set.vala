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
      this.add_test ("bgo640551", this.test_bgo640551);
      this.add_test ("iterator", this.test_iterator);
      this.add_test ("iterator removal", this.test_iterator_removal);
      this.add_test ("iterator empty", this.test_iterator_empty);
      this.add_test ("iterator navigation", this.test_iterator_navigation);
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

  /* derive a new string from the given one (purely for checking for leaks) */
  private string _normalise_key (string key)
    {
      return key.down ();
    }

  public void test_bgo640551 ()
    {
      /* This resembles the compound structure used by the Telepathy backend's
       * ImDetails implementation in Tpf.Persona (which has caused memory leaks
       * in the past - see bgo#640551) */
      var global_im_addresses =
          new HashTable<string, LinkedHashSet<string>> (str_hash, str_equal);
      var im_address_set = new LinkedHashSet<string> ();
      const string protocol = "foo protocol";
      const string address = "bar@example.org";
      const string address2 = "bar2@example.org";

      im_address_set.add (this._normalise_key (address));
      im_address_set.add (this._normalise_key (address2));

      var im_addresses =
          new HashTable<string, LinkedHashSet<string>> (str_hash, str_equal);
      im_addresses.insert (protocol, im_address_set);

      im_addresses.foreach ((k, v) =>
        {
          var cur_protocol = (string) k;
          var cur_addresses = (LinkedHashSet<string>) v;
          var im_set = global_im_addresses.lookup (cur_protocol);

          if (im_set == null)
            {
              im_set = new LinkedHashSet<string> ();
              global_im_addresses.insert (cur_protocol, im_set);
            }

          im_set.add_all (cur_addresses);
        });
    }

  /* Test that LinkedHashSet.iterator() works at a basic level */
  public void test_iterator ()
    {
      HashSet<int> values = new HashSet<int> ();
      LinkedHashSet<int> lhs = new LinkedHashSet<int> ();

      /* Set up the values and insert them into the HashSet */
      for (var i = 0; i < 10; i++)
        {
          values.add (i);
          lhs.add (i);
        }

      /* We don't make any assertions about the order; just that exactly the
       * right set of values is returned by the iterator. */
      var iter = lhs.iterator ();

      while (iter.next ())
        {
          var i = iter.get ();
          assert (values.remove (i));
        }

      assert (values.size == 0);
    }

  public void test_iterator_removal ()
    {
      LinkedHashSet<int> lhs = new LinkedHashSet<int> ();

      /* Set up the values and insert them into the HashSet */
      for (var i = 0; i < 10; i++)
        lhs.add (i);

      /* Remove all the entries from the LinkedHashSet via Iterator.remove().
       * Then, check that they've been removed. */
      var iter = lhs.iterator ();

      while (iter.next ())
        iter.remove ();

      assert (lhs.size == 0);

      for (var i = 0; i < 10; i++)
        assert (!lhs.contains (i));
    }

  public void test_iterator_empty ()
    {
      LinkedHashSet<int> lhs = new LinkedHashSet<int> ();
      var _iter = lhs.iterator ();
      assert (_iter is BidirIterator);
      var iter = (BidirIterator<int>) _iter;

      /* Check the iterator behaves correctly for an empty LinkedHashSet */
      assert (!iter.next ());
      assert (!iter.has_next ());
      assert (!iter.first ());
      assert (!iter.previous ());
      assert (!iter.has_previous ());
      assert (!iter.last ());
    }

  public void test_iterator_navigation ()
    {
      LinkedHashSet<int> lhs = new LinkedHashSet<int> ();

      lhs.add (0);
      lhs.add (1);
      lhs.add (2);

      var _iter = lhs.iterator ();
      assert (_iter is BidirIterator);
      var iter = (BidirIterator<int>) _iter;

      assert (iter.has_next ());
      assert (!iter.has_previous ());
      assert (iter.next ());
      assert (iter.get () == 0);

      assert (iter.first ());
      assert (iter.get () == 0);

      assert (iter.has_next ());
      assert (iter.next ());
      assert (iter.has_previous ());
      assert (iter.get () == 1);

      assert (iter.first ());
      assert (iter.get () == 0);

      assert (iter.next ());
      assert (iter.next ());
      assert (iter.get () == 2);
      assert (!iter.has_next ());
      assert (iter.has_previous ());

      assert (iter.last ());
      assert (iter.get () == 2);

      assert (iter.previous ());
      assert (iter.get () == 1);
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
