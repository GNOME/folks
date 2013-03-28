/*
 * Copyright © 2013 Intel Corporation
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
 * Authors:
 *      Simon McVittie <simon.mcvittie@collabora.co.uk>
 */

using Gee;
using Folks;

/* An object with no equality pseudo-operator. */
public class DirectEq : Object
{
  public uint u;

  public DirectEq (uint u)
    {
      this.u = u;
    }
}

/* An object with an equality pseudo-operator. */
public class UInt : Object
{
  public uint u;

  public UInt (uint u)
    {
      this.u = u;
    }

  public static uint hash_static (UInt that)
    {
      return that.u;
    }

  public static bool equals_static (UInt left, UInt right)
    {
      return left.u == right.u;
    }
}

public class SmallSetTests : Folks.TestCase
{
  public SmallSetTests ()
    {
      base ("SmallSet");
      this.add_test ("objects_hash", () => this.test_objects (true));
      this.add_test ("objects", () => this.test_objects (false));
      this.add_test ("iter_hash", () => this.test_iter (true));
      this.add_test ("iter", () => this.test_iter (false));
      this.add_test ("readonly_hash", () => this.test_readonly (true));
      this.add_test ("readonly", () => this.test_readonly (false));
      this.add_test ("direct_hash", () => this.test_direct (true));
      this.add_test ("direct", () => this.test_direct (false));
      this.add_test ("string_hash", () => this.test_strings (true));
      this.add_test ("string", () => this.test_strings (false));
      this.add_test ("cheating", this.test_cheating);
    }

  public void test_objects (bool use_hash)
    {
      var small = new SmallSet<UInt> (UInt.hash_static, UInt.equals_static);
      var hash = new HashSet<UInt> (UInt.hash_static, UInt.equals_static);

      Set<UInt> objects = (use_hash ? hash as Set<UInt> : small as Set<UInt>);

      assert (objects != null);
      assert (!objects.read_only);
      assert (objects.size == 0);
      assert (objects.is_empty);

      objects.add (new UInt (10000));
      objects.add (new UInt (1));
      objects.add (new UInt (10));
      objects.add (new UInt (100));
      objects.add (new UInt (1000));

      assert (objects != null);
      assert (!objects.read_only);
      assert (!objects.is_empty);
      assert (objects.size == 5);

      uint sum = 0;
      bool res = objects.foreach ((obj) =>
        {
          sum += obj.u;
          return true;
        });

      /* FIXME: this used to be wrong in HashSet (GNOME #696710).
       * Do this unconditionally when we depend on a Gee with that fixed */
      if (!use_hash)
        assert (res == true);

      assert (sum == 11111);

      sum = 0;
      res = objects.foreach ((obj) =>
        {
          sum += obj.u;
          return false;
        });
      assert (res == false);
      assert (sum == 1 || sum == 10 || sum == 100 || sum == 1000 ||
        sum == 10000);

      var ten = new UInt (10);

      objects.foreach ((obj) =>
        {
          /* It is not the same object as the one in the set... */
          assert (ten != obj);
          return true;
        });

      /* ... but it is equal, and that'll do */
      assert (objects.contains (ten));
      /* Vala syntactic sugar */
      assert (ten in objects);
      /* It's a set. Attempts to add a duplicate are ignored. */
      res = objects.add (ten);
      assert (res == false);
      assert (objects.size == 5);
      objects.foreach ((obj) =>
        {
          assert (ten != obj);
          return true;
        });

      objects.remove (ten);

      /* Vala syntactic sugar: behind the scenes, this uses an iterator */
      sum = 0;
      foreach (var obj in objects)
        sum += obj.u;
      assert (sum == 11101);

      /* Put it back. */
      res = objects.add (ten);
      assert (res == true);

      sum = 0;
      foreach (var obj in objects)
        sum += obj.u;
      assert (sum == 11111);

      objects.clear ();
      assert (objects.size == 0);
      assert (objects.is_empty);
      foreach (var obj in objects)
        assert_not_reached ();
    }

  public void test_iter (bool use_hash)
    {
      var small = new SmallSet<UInt> (UInt.hash_static, UInt.equals_static);
      var hash = new HashSet<UInt> (UInt.hash_static, UInt.equals_static);

      Set<UInt> objects = (use_hash ? hash as Set<UInt> : small as Set<UInt>);

      var iter = objects.iterator ();   /* points before 0 - invalid */
      assert (!iter.valid);
      assert (!iter.read_only);
      assert (!iter.has_next ());
      bool res = iter.next ();          /* fails, remains pointing before 0 */
      assert (!res);
      assert (!iter.valid);
      assert (!iter.has_next ());

      objects.add (new UInt (1));
      objects.add (new UInt (10));
      objects.add (new UInt (100));
      objects.add (new UInt (1000));
      objects.add (new UInt (10000));
      assert (objects.size == 5);

      iter = objects.iterator ();       /* points before 0 - invalid */

      assert (!iter.valid);
      assert (!iter.read_only);

      assert (iter.has_next ());
      res = iter.next ();               /* points to 0 */
      assert (res);
      assert (iter.valid);
      assert (iter.has_next ());

      iter.next ();                     /* points to 1 */
      iter.next ();                     /* points to 2 */
      iter.next ();                     /* points to 3 */
      assert (iter.valid);
      assert (iter.has_next ());
      iter.next ();                     /* points to 4 */
      assert (iter.valid);
      assert (!iter.has_next ());
      res = iter.next ();               /* fails, remains pointing to 4 */
      assert (!res);
      assert (iter.valid);              /* still valid */
      assert (!iter.has_next ());

      iter = objects.iterator ();
      uint sum = 0;
      /* If the iterator has not been started then iter.foreach starts from
       * the beginning, skipping any prior items. */
      iter.foreach ((obj) =>
        {
          sum += obj.u;
          return true;
        });
      assert (sum == 11111);

      sum = 0;
      iter = objects.iterator ();
      res = iter.foreach ((obj) =>
        {
          sum += obj.u;
          return false;
        });
      assert (res == false);
      assert (sum == 1 || sum == 10 || sum == 100 || sum == 1000 ||
        sum == 10000);

      sum = 0;
      iter = objects.iterator ();
      iter.next ();
      sum += iter.get ().u;
      iter.next ();
      sum += iter.get ().u;
      iter.next ();
      /* If iter.valid then iter.foreach starts from the current item,
       * skipping any prior items. We already added the ones we expect to
       * have skipped. */
      iter.foreach ((obj) =>
        {
          sum += obj.u;
          return true;
        });
      assert (sum == 11111);

      sum = 0;
      iter = objects.iterator ();
      iter.next ();
      iter.next ();
      iter.next ();
      iter.next ();
      iter.next ();
      iter.foreach ((obj) =>
        {
          /* only run for the current == last item */
          sum += 1;
          return true;
        });
      assert (sum == 1);

      /* Remove the first element. */
      sum = 0;
      iter = objects.iterator ();
      iter.next ();
      assert (iter.valid);
      var removed = iter.get ();
      iter.remove ();
      sum += removed.u;
      assert (!iter.valid);
      while (iter.next ())
        sum += iter.get ().u;
      assert (sum == 11111);
      /* Put it back. */
      objects.add (removed);

      /* Remove a middle element. */
      sum = 0;
      iter = objects.iterator ();
      iter.next ();
      sum += iter.get ().u;
      iter.next ();
      sum += iter.get ().u;
      iter.next ();
      assert (iter.valid);
      removed = iter.get ();
      iter.remove ();
      sum += removed.u;
      assert (!iter.valid);
      while (iter.next ())
        sum += iter.get ().u;
      assert (sum == 11111);
      /* Put it back. */
      objects.add (removed);

      /* Remove the last element. */
      sum = 0;
      iter = objects.iterator ();
      iter.next ();
      iter.next ();
      iter.next ();
      iter.next ();
      iter.next ();
      assert (iter.valid);
      assert (!iter.has_next ());
      removed = iter.get ();
      iter.remove ();
      sum += removed.u;
      assert (!iter.valid);
      assert (!iter.has_next ());
      foreach (var obj in objects)
        sum += obj.u;
      assert (sum == 11111);
      /* Put it back. */
      objects.add (removed);
    }

  public void test_readonly (bool use_hash)
    {
      var small = new SmallSet<UInt> (UInt.hash_static, UInt.equals_static);
      var hash = new HashSet<UInt> (UInt.hash_static, UInt.equals_static);

      Set<UInt> objects = (use_hash ? hash as Set<UInt> : small as Set<UInt>);

      var ro = objects.read_only_view;
      assert (ro != null);
      assert (ro != objects);
      assert (ro.read_only);
      assert (ro.size == 0);

      objects.add (new UInt (23));
      assert (objects.size == 1);
      assert (ro.size == 1);

      uint u = 0;
      ro.foreach ((obj) =>
        {
          assert (u == 0);
          u = obj.u;
          return true;
        });
      assert (u == 23);

      var iter = ro.iterator ();
      assert (iter.read_only);
      u = 0;
      iter.foreach ((obj) =>
        {
          assert (u == 0);
          u = obj.u;
          return true;
        });
      assert (u == 23);

      /* These are implementation details */
      if (!use_hash)
        {
          /* A new read-only view of an object is not the same thing yet */
          var ro2 = objects.read_only_view;
          assert (ro != ro2);

          /* The read-only view of a read-only view is itself */
          ro2 = ro.read_only_view;
          assert (ro == ro2);
        }
    }

  public void test_direct (bool use_hash)
    {
      var small = new SmallSet<DirectEq> ();
      var hash = new HashSet<DirectEq> ();

      Set<DirectEq> objects = (use_hash ?
          hash as Set<DirectEq> : small as Set<DirectEq>);

      objects.add (new DirectEq (23));
      objects.add (new DirectEq (23));
      var fortytwo = new DirectEq (42);
      objects.add (fortytwo);
      objects.add (fortytwo);
      assert (objects.size == 3);

      uint sum = 0;
      foreach (var obj in objects)
        sum += obj.u;
      assert (sum == 23 + 23 + 42);
    }

  public void test_strings (bool use_hash)
    {
      var small = new SmallSet<string> ();
      var hash = new HashSet<string> ((Gee.HashDataFunc) str_hash,
          (Gee.EqualDataFunc) str_equal);

      Set<string> strings = (use_hash ?
          hash as Set<string> : small as Set<string>);

      strings.add ("cheese");
      strings.add ("cheese");
      strings.add ("ham");
      assert (strings.size == 2);
    }

  public void test_cheating ()
    {
      var small = new SmallSet<UInt> (UInt.hash_static, UInt.equals_static);
      var set_ = (!) (small as Set<UInt>);

      small.add (new UInt (1));
      small.add (new UInt (10));
      small.add (new UInt (100));
      small.add (new UInt (1000));
      small.add (new UInt (10000));

      int i = 0;
      set_.iterator ().foreach ((obj) =>
        {
          /* Fast-path: get() provides indexed access */
          assert (small[i] == obj);
          i++;
          return true;
        });
      assert (i == 5);

      /* Slow iteration: we don't know, syntactically, that set_ is a
       * SmallSet, so we'll use the iterator */
      uint sum = 0;
      foreach (var obj in set_)
        sum += obj.u;
      assert (sum == 11111);

      /* Fast iteration: we do know, syntactically, that small is a
       * SmallSet, so we'll use indexed access */
      sum = 0;
      foreach (unowned UInt obj in small)
        sum += obj.u;
      assert (sum == 11111);
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new SmallSetTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
