using Gee;
using Folks;

/* Dummy ObjectCache subclass */
internal class TestObject
{
  public string my_string { get; set; }
  public uint my_int { get; set; }

  public TestObject (string my_string, uint my_int)
    {
      this.my_string = my_string;
      this.my_int = my_int;
    }
}

internal class TestCache : Folks.ObjectCache<TestObject>
{
  internal TestCache (string id)
    {
      base ("test", id);
    }

  protected override VariantType? get_serialised_object_type (
      uint8 object_version)
    {
      return new VariantType.tuple ({
        VariantType.STRING,
        VariantType.UINT32
      });
    }

  protected override uint8 get_serialised_object_version ()
    {
      return 1;
    }

  protected override Variant serialise_object (TestObject obj)
    {
      return new Variant.tuple ({
        new Variant.string (obj.my_string),
        new Variant.uint32 (obj.my_int)
      });
    }

  protected override TestObject deserialise_object (Variant variant,
      uint8 object_version)
    {
      // Deserialise the persona
      var my_string = variant.get_child_value (0).get_string ();
      var my_int = variant.get_child_value (1).get_uint32 ();

      return new TestObject (my_string, my_int);
    }
}

/* Test suite */
public class ObjectCacheTests : Folks.TestCase
{
  private File _cache_dir;

  public ObjectCacheTests ()
    {
      base ("ObjectCache");

      /* Use a temporary cache directory */
      /* FIXME: Use g_dir_make_tmp() but it is not bound: #672846 */
      var tmp_path = Environment.get_tmp_dir () + "/folks-object-cache-tests";
      Environment.set_variable ("XDG_CACHE_HOME", tmp_path, true);
      assert (Environment.get_user_cache_dir () == tmp_path);
      this._cache_dir = File.new_for_path (tmp_path);

      // Basic functionality tests
      this.add_test ("create", this.test_create);
      this.add_test ("store-objects", this.test_store_objects);
      this.add_test ("store-objects-empty", this.test_store_objects_empty);
      this.add_test ("load-objects", this.test_load_objects);
      this.add_test ("load-objects-empty", this.test_load_objects_empty);
      this.add_test ("load-objects-nonexistent",
          this.test_load_objects_nonexistent);
      this.add_test ("clear", this.test_clear);
      this.add_test ("clear-empty", this.test_clear_empty);
      this.add_test ("clear-nonexistent", this.test_clear_nonexistent);

      // Cancellation tests
      this.add_test ("store-objects-cancellation",
          this.test_store_objects_cancellation);
      this.add_test ("load-objects-cancellation",
          this.test_load_objects_cancellation);

      // Stress test
      this.add_test ("stress", this.test_stress);
    }

  public override void set_up ()
    {
      base.set_up ();
      this._delete_cache_directory ();
    }

  public override void tear_down ()
    {
      this._delete_cache_directory ();
      base.tear_down ();
    }

  protected void _delete_directory (File dir) throws GLib.Error
    {
      // Delete the files in the directory
      var enumerator =
          dir.enumerate_children (FileAttribute.STANDARD_NAME,
              FileQueryInfoFlags.NONE);

      FileInfo? file_info = enumerator.next_file ();
      while (file_info != null)
        {
          var child_file = dir.get_child (file_info.get_name ());

          if (child_file.query_file_type (FileQueryInfoFlags.NONE) ==
                  FileType.DIRECTORY)
            {
              this._delete_directory (child_file);
            }
          else
            {
              child_file.delete ();
            }

          file_info = enumerator.next_file ();
        }
      enumerator.close ();

      // Delete the directory itself
      dir.delete ();
    }

  protected void _delete_cache_directory ()
    {
      try
        {
          this._delete_directory (this._cache_dir);
        }
      catch (Error e)
        {
          // Ignore it
        }
    }

  public void test_create ()
    {
      // Does creating a cache object work?
      var cache = new TestCache ("test-create");

      assert (cache != null);
    }

  public void test_store_objects ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var cache = new TestCache ("test-store-objects");

      var obj_set = new HashSet<TestObject> ();
      obj_set.add (new TestObject ("Foo", 1));
      obj_set.add (new TestObject ("Bar", 2));
      obj_set.add (new TestObject ("De", 3));
      obj_set.add (new TestObject ("Baz", 4));

      cache.store_objects.begin (obj_set, null, (o, r) =>
        {
          cache.store_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();
    }

  public void test_store_objects_empty ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var cache = new TestCache ("test-store-objects-empty");

      cache.store_objects.begin (new HashSet<TestObject> (), null, (o, r) =>
        {
          cache.store_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();
    }

  public void test_load_objects ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var cache = new TestCache ("test-load-objects");

      // Create some objects
      var obj1 = new TestObject ("Foo", 1);
      var obj2 = new TestObject ("Bar", 2);

      var obj_set = new HashSet<TestObject> ();
      obj_set.add (obj1);
      obj_set.add (obj2);

      // Store the objects
      cache.store_objects.begin (obj_set, null, (o, r) =>
        {
          cache.store_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      // Load the objects
      Set<TestObject>? new_obj_set = null;
      cache.load_objects.begin (null, (o, r) =>
        {
          new_obj_set = cache.load_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      // Check the objects
      assert (new_obj_set != null);
      assert (new_obj_set.size == obj_set.size);

      foreach (var new_obj in new_obj_set)
        {
          bool partner_found = false;

          foreach (var original_obj in obj_set)
            {
              if (new_obj.my_string == original_obj.my_string &&
                  new_obj.my_int == original_obj.my_int)
                {
                  obj_set.remove (original_obj);
                  partner_found = true;
                  break;
                }
            }

          assert (partner_found);
        }

      assert (obj_set.size == 0);
    }

  public void test_load_objects_empty ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var cache = new TestCache ("test-load-objects-empty");

      // Store an empty set of objects
      cache.store_objects.begin (new HashSet<TestObject> (), null, (o, r) =>
        {
          cache.store_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      // Load the set
      Set<TestObject>? new_obj_set = null;
      cache.load_objects.begin (null, (o, r) =>
        {
          new_obj_set = cache.load_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      // Check the set
      assert (new_obj_set != null);
      assert (new_obj_set.size == 0);
    }

  public void test_load_objects_nonexistent ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var cache = new TestCache ("test-load-objects-nonexistent");

      // Remove the cache directory
      this._delete_cache_directory ();

      // Load the cache file
      Set<TestObject>? new_obj_set = null;
      cache.load_objects.begin (null, (o, r) =>
        {
          new_obj_set = cache.load_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      // Check the set is nonexistent
      assert (new_obj_set == null);
    }

  public void test_clear ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var cache = new TestCache ("test-clear");

      // Create some objects
      var obj1 = new TestObject ("Foo", 1);
      var obj2 = new TestObject ("Bar", 2);

      var obj_set = new HashSet<TestObject> ();
      obj_set.add (obj1);
      obj_set.add (obj2);

      // Store the objects
      cache.store_objects.begin (obj_set, null, (o, r) =>
        {
          cache.store_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      // Clear the cache
      cache.clear_cache.begin ((o, r) =>
        {
          cache.clear_cache.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      // Attempt to load the cache file. This should fail.
      Set<TestObject>? new_obj_set = null;
      cache.load_objects.begin (null, (o, r) =>
        {
          new_obj_set = cache.load_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      assert (new_obj_set == null);
    }

  public void test_clear_empty ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var cache = new TestCache ("test-clear-empty");

      // Store an empty set
      cache.store_objects.begin (new HashSet<TestObject> (), null, (o, r) =>
        {
          cache.store_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      // Clear the cache
      cache.clear_cache.begin ((o, r) =>
        {
          cache.clear_cache.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      // Attempt to load the cache file. This should fail.
      Set<TestObject>? new_obj_set = null;
      cache.load_objects.begin (null, (o, r) =>
        {
          new_obj_set = cache.load_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      assert (new_obj_set == null);
    }

  public void test_clear_nonexistent ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var cache = new TestCache ("test-clear-nonexistent");

      // Remove the cache directory
      this._delete_cache_directory ();

      // Clear the cache
      cache.clear_cache.begin ((o, r) =>
        {
          cache.clear_cache.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      // Attempt to load the cache file. This should fail.
      Set<TestObject>? new_obj_set = null;
      cache.load_objects.begin (null, (o, r) =>
        {
          new_obj_set = cache.load_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      assert (new_obj_set == null);
    }

  public void test_store_objects_cancellation ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var cache = new TestCache ("test-store-objects-cancellation");

      var obj_set = new HashSet<TestObject> ();
      obj_set.add (new TestObject ("Foo", 1));
      obj_set.add (new TestObject ("Bar", 2));
      obj_set.add (new TestObject ("De", 3));
      obj_set.add (new TestObject ("Baz", 4));

      var cancellable = new Cancellable ();

      cache.store_objects.begin (obj_set, cancellable, (o, r) =>
        {
          cache.store_objects.end (r);
          main_loop.quit ();
        });

      // Cancel the operation before running the main loop
      cancellable.cancel ();
      main_loop.run ();

      // Check that loading the objects fails (i.e. storing them failed)
      Set<TestObject>? new_obj_set = null;
      cache.load_objects.begin (null, (o, r) =>
        {
          new_obj_set = cache.load_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      assert (new_obj_set == null);
    }

  public void test_load_objects_cancellation ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var cache = new TestCache ("test-load-objects-cancellation");

      // Create some objects
      var obj1 = new TestObject ("Foo", 1);
      var obj2 = new TestObject ("Bar", 2);

      var obj_set = new HashSet<TestObject> ();
      obj_set.add (obj1);
      obj_set.add (obj2);

      // Store the objects
      cache.store_objects.begin (obj_set, null, (o, r) =>
        {
          cache.store_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      // Load the objects and check that nothing is returned
      var cancellable = new Cancellable ();

      Set<TestObject>? new_obj_set = null;
      cache.load_objects.begin (cancellable, (o, r) =>
        {
          new_obj_set = cache.load_objects.end (r);
          main_loop.quit ();
        });

      // Cancel the operation before running the main loop
      cancellable.cancel ();
      main_loop.run ();

      assert (new_obj_set == null);
    }

  public void test_stress ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var cache = new TestCache ("test-stress");

      // Create a handful of objects
      var obj_count = 66666;
      var obj_set = new HashSet<TestObject> ();

      for (var i = 0; i < obj_count; i++)
        {
          obj_set.add (new TestObject ("bizzle", i));
        }

      // Store the objects
      Test.timer_start ();

      cache.store_objects.begin (obj_set, null, (o, r) =>
        {
          var elapsed_time = Test.timer_elapsed ();
          message ("Storing %u objects in a cache file took %f seconds.",
              obj_count, elapsed_time);

          cache.store_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      // Load the objects
      Test.timer_start ();

      Set<TestObject>? new_obj_set = null;
      cache.load_objects.begin (null, (o, r) =>
        {
          var elapsed_time = Test.timer_elapsed ();
          message ("Loading %u objects from a cache file took %f seconds.",
              obj_count, elapsed_time);

          new_obj_set = cache.load_objects.end (r);
          main_loop.quit ();
        });

      main_loop.run ();

      /* Check the set is the right size. We don't bother to check that the
       * objects themselves are OK — the loading tests do that. */
      assert (new_obj_set != null);
      assert (new_obj_set.size == obj_set.size);
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new ObjectCacheTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}

/* vim: filetype=vala textwidth=80 tabstop=2 expandtab: */
