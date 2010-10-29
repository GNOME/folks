using Gee;
using Folks;

public class BackendLoadingTests : Folks.TestCase
{
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
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
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
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new BackendLoadingTests ().get_suite ());

  Test.run ();

  return 0;
}
