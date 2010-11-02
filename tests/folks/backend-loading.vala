using Gee;
using Folks;

public class BackendLoadingTests : Folks.TestCase
{
  private MainLoop main_loop;
  private static const string STORE_FILE_PATH = "folks-test-backend-store.ini";

  public BackendLoadingTests ()
    {
      base ("BackendLoading");

      /* Ignore the error caused by not running the logger */
      Test.log_set_fatal_handler ((d, l, m) =>
        {
          return !m.has_suffix ("couldn't get list of favourite contacts: " +
              "The name org.freedesktop.Telepathy.Logger was not provided by " +
              "any .service files");
        });

      this.add_test ("load and prep", this.test_load_and_prep);
      this.add_test ("disabling", this.test_disabling);
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
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new BackendLoadingTests ().get_suite ());

  Test.run ();

  return 0;
}
