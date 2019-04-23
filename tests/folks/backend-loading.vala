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

public class BackendLoadingTests : TpfTest.MixedTestCase
{
  private MainLoop main_loop;
  private const string STORE_FILE_PATH = "folks-test-backend-store.ini";

  public BackendLoadingTests ()
    {
      base ("BackendLoading");

      this.add_test ("load and prep", this.test_load_and_prep);
      this.add_test ("disabling", this.test_disabling);
      this.add_test ("reloading", this.test_reloading);
    }

  public override void set_up ()
    {
      base.set_up ();

      /* Use a temporary key file for the BackendStore */
      var kf_path = Path.build_filename (Environment.get_tmp_dir (),
          STORE_FILE_PATH, null);

      FileUtils.remove (kf_path);

      GLib.KeyFile kf = new GLib.KeyFile ();
      kf.set_boolean("all-others", "enabled", false);
      kf.set_boolean("telepathy", "enabled", true);
      kf.set_boolean("key-file", "enabled", true);

      try
        {
          File backend_f = File.new_for_path (kf_path);
          string data = kf.to_data ();
          backend_f.replace_contents (data.data,
              null, false, FileCreateFlags.PRIVATE,
              null, null);
        }
      catch (Error e)
        {
          warning ("Could not write updated backend key file '%s': %s",
              kf_path, e.message);
        }

      Environment.set_variable ("FOLKS_BACKEND_STORE_KEY_FILE_PATH",
          kf_path, true);
    }

  public override void tear_down ()
    {
      FileUtils.remove (Path.build_filename (Environment.get_tmp_dir (),
          STORE_FILE_PATH, null));

      base.tear_down ();
    }

  public void test_load_and_prep ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var backends_expected = new HashSet<string> ();

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

              foreach (var backend in store.enabled_backends.values)
                {
                  assert (backends_expected.contains (backend.name));
                  backends_expected.remove (backend.name);
                }

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
      this.test_disabling_async.begin (store, (o, r) =>
        {
          this.test_disabling_async.end (r);
        });

      this.main_loop.run ();
    }

  private async void test_disabling_async (BackendStore store)
    {
      var backends_expected = new HashSet<string> ();
      backends_expected.add ("key-file");

      /* Disable some backends */
      yield store.prepare ();
      yield store.disable_backend ("telepathy");

      try
        {
          yield store.load_backends ();

          foreach (var backend in store.enabled_backends.values)
            {
              assert (backends_expected.contains (backend.name));
              backends_expected.remove (backend.name);
            }

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
      this.test_reloading_async.begin (store, (o, r) =>
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
      backends_expected = new HashSet<string> ();
      backends_expected.add ("key-file");
      backends_expected.add ("telepathy");

      try
        {
          yield store.load_backends ();

          foreach (var backend1 in store.enabled_backends.values)
            {
              assert (backends_expected.contains (backend1.name));
              backends_expected.remove (backend1.name);
            }

          assert (backends_expected.size == 0);
        }
      catch (GLib.Error e1)
        {
          GLib.error ("Failed to load backends: %s", e1.message);
        }

      /*
       * Second loading: late disabling
       */
      backends_expected = new HashSet<string> ();
      backends_expected.add ("telepathy");

      /* Disable some backends */
      yield store.disable_backend ("key-file");

      /* this time we should get (all - key-file) */
      try
        {
          yield store.load_backends ();

          foreach (var backend2 in store.enabled_backends.values)
            {
              assert (backends_expected.contains (backend2.name));
              backends_expected.remove (backend2.name);
            }

          assert (backends_expected.size == 0);
        }
      catch (GLib.Error e2)
        {
          GLib.error ("Failed to load backends: %s", e2.message);
        }

      /*
       * Third loading: late enabling
       */
      backends_expected = new HashSet<string> ();
      backends_expected.add ("key-file");
      backends_expected.add ("telepathy");

      /* Re-enable some backends */
      yield store.enable_backend ("key-file");

      /* this time we should get them all */
      try
        {
          yield store.load_backends ();

          foreach (var backend3 in store.enabled_backends.values)
            {
              assert (backends_expected.contains (backend3.name));
              backends_expected.remove (backend3.name);
            }

          assert (backends_expected.size == 0);
        }
      catch (GLib.Error e3)
        {
          GLib.error ("Failed to load backends: %s", e3.message);
        }

      /*
       * Fourth loading: idempotency
       */

      backends_expected = new HashSet<string> ();
      backends_expected.add ("key-file");
      backends_expected.add ("telepathy");

      /* this time we should get them all */
      try
        {
          yield store.load_backends ();

          foreach (var backend in store.enabled_backends.values)
            {
              assert (backends_expected.contains (backend.name));
              backends_expected.remove (backend.name);
            }

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

  var tests = new BackendLoadingTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
