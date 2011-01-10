using Gee;
using Folks;

public class BackendLoadingTests : Folks.TestCase
{
  private MainLoop main_loop;
  private static const string STORE_FILE_PATH = "folks-test-backend-store.ini";

  public BackendLoadingTests ()
    {
      base ("BackendLoading");

      this.add_test ("load and prep", this.test_load_and_prep);
      this.add_test ("disabling", this.test_disabling);
      this.add_test ("reloading", this.test_reloading);
    }

  public override void set_up ()
    {
      FileUtils.remove (Path.build_filename (Environment.get_tmp_dir (),
          this.STORE_FILE_PATH, null));

      /* Use a temporary key file for the BackendStore */
      Environment.set_variable ("FOLKS_BACKEND_STORE_KEY_FILE_PATH",
          Path.build_filename (Environment.get_tmp_dir (),
              this.STORE_FILE_PATH, null), true);
    }

  public override void tear_down ()
    {
      FileUtils.remove (Path.build_filename (Environment.get_tmp_dir (),
          this.STORE_FILE_PATH, null));
    }

  public void test_load_and_prep ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var backends_expected = new HashSet<string> (str_hash, str_equal);

      backends_expected.add ("key-file");
      backends_expected.add ("telepathy");

      var store = BackendStore.dup ();
      store.prepare.begin ((o, r) =>
        {
          store.prepare.end (r);
        });

      store.load_backends.begin ((o, r) =>
        {
          try
            {
              store.load_backends.end (r);

              store.enabled_backends.foreach ((i) =>
                {
                  var backend = (Backend) i;
                  assert (backends_expected.contains (backend.name));
                  backends_expected.remove (backend.name);
                });

              assert (backends_expected.size == 0);
              main_loop.quit ();
            }
          catch (GLib.Error e)
            {
              GLib.error ("Failed to load backends: %s", e.message);
            }
        });

      main_loop.run ();
    }

  public void test_disabling ()
    {
      this.main_loop = new GLib.MainLoop (null, false);

      var store = BackendStore.dup ();
      this.test_disabling_async (store, (o, r) =>
        {
          this.test_disabling_async.end (r);
        });

      this.main_loop.run ();
    }

  private async void test_disabling_async (BackendStore store)
    {
      var backends_expected = new HashSet<string> (str_hash, str_equal);
      backends_expected.add ("key-file");

      /* Disable some backends */
      yield store.prepare ();
      yield store.disable_backend ("telepathy");

      try
        {
          yield store.load_backends ();

          store.enabled_backends.foreach ((i) =>
            {
              var backend = (Backend) i;
              assert (backends_expected.contains (backend.name));
              backends_expected.remove (backend.name);
            });

          assert (backends_expected.size == 0);
          this.main_loop.quit ();
        }
      catch (GLib.Error e)
        {
          GLib.error ("Failed to load backends: %s", e.message);
        }
    }

  public void test_reloading ()
    {
      this.main_loop = new GLib.MainLoop (null, false);

      var store = BackendStore.dup ();
      this.test_reloading_async (store, (o, r) =>
        {
          this.test_reloading_async.end (r);
        });

      main_loop.run ();
    }

  private async void test_reloading_async (BackendStore store)
    {
      HashSet<string> backends_expected;

      /*
       * First loading
       */
      backends_expected = new HashSet<string> (str_hash, str_equal);
      backends_expected.add ("key-file");
      backends_expected.add ("telepathy");

      try
        {
          yield store.load_backends ();

          store.enabled_backends.foreach ((i) =>
            {
              var backend = (Backend) i;
              assert (backends_expected.contains (backend.name));
              backends_expected.remove (backend.name);
            });

          assert (backends_expected.size == 0);
        }
      catch (GLib.Error e1)
        {
          GLib.error ("Failed to load backends: %s", e1.message);
        }

      /*
       * Second loading: late disabling
       */
      backends_expected = new HashSet<string> (str_hash, str_equal);
      backends_expected.add ("telepathy");

      /* Disable some backends */
      yield store.disable_backend ("key-file");

      /* this time we should get (all - key-file) */
      try
        {
          yield store.load_backends ();

          store.enabled_backends.foreach ((i) =>
            {
              var backend = (Backend) i;
              assert (backends_expected.contains (backend.name));
              backends_expected.remove (backend.name);
            });

          assert (backends_expected.size == 0);
        }
      catch (GLib.Error e2)
        {
          GLib.error ("Failed to load backends: %s", e2.message);
        }

      /*
       * Third loading: late enabling
       */
      backends_expected = new HashSet<string> (str_hash, str_equal);
      backends_expected.add ("key-file");
      backends_expected.add ("telepathy");

      /* Re-enable some backends */
      yield store.enable_backend ("key-file");

      /* this time we should get them all */
      try
        {
          yield store.load_backends ();

          store.enabled_backends.foreach ((i) =>
            {
              var backend = (Backend) i;
              assert (backends_expected.contains (backend.name));
              backends_expected.remove (backend.name);
            });

          assert (backends_expected.size == 0);
        }
      catch (GLib.Error e3)
        {
          GLib.error ("Failed to load backends: %s", e3.message);
        }

      /*
       * Fourth loading: idempotency
       */

      backends_expected = new HashSet<string> (str_hash, str_equal);
      backends_expected.add ("key-file");
      backends_expected.add ("telepathy");

      /* this time we should get them all */
      try
        {
          yield store.load_backends ();

          store.enabled_backends.foreach ((i) =>
            {
              var backend = (Backend) i;

              assert (backends_expected.contains (backend.name));
              backends_expected.remove (backend.name);
            });

          assert (backends_expected.size == 0);
        }
      catch (GLib.Error e4)
        {
          GLib.error ("Failed to load backends: %s", e4.message);
        }

      this.main_loop.quit ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new BackendLoadingTests ().get_suite ());

  Test.run ();

  return 0;
}
