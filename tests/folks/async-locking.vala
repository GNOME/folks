using Gee;
using GLib;

public class AsyncLockingTests : Folks.TestCase
{
  int _counter;
  bool _counter_increment_pending;
  int _calls_pending;
  int _total_calls;
  MainLoop _loop;

  // This test was added to ensure removing lock (this._is_prepared) in prepare
  // Methods is not going to cause a problem.
  // See bug: https://bugzilla.gnome.org/show_bug.cgi?id=652637
  public AsyncLockingTests ()
    {
      base ("AsyncLocking");
      this.add_test ("many concurrent funcs", this.test_many_concurrent_funcs);
      this.add_test ("many concurrent funcs (safe)",
          this.test_many_concurrent_funcs_safe);
    }

  public override void set_up ()
    {
      base.set_up ();
      this._counter = 0;
      this._calls_pending = 0;
      this._counter_increment_pending = false;
    }

  public void test_many_concurrent_funcs ()
    {
      _loop = new GLib.MainLoop (null, false);
      this._total_calls = 100;

      Idle.add (() =>
        {
          for (var i = 0; i < this._total_calls; i++)
            {
              this._calls_pending++;
              locked_increment.begin (increment_handler);
            }

          return false;
        });

      _loop.run ();
    }

  private void increment_handler (GLib.Object? source, GLib.AsyncResult result)
    {
      locked_increment.end (result);

      /* calls expect the end state when they reach this point */
      assert (this._counter >= 1);

      this._calls_pending--;
      if (this._calls_pending == 0)
        {
          print ("\n    final counter value: %d " +
              "(would be 1 if this weren't intentionally broken)\n",
              this._counter);
          this._loop.quit ();
        }
    }

  private async void locked_increment ()
    {
      lock (this._counter)
        {
          if (this._counter < 1)
            {
              /* In this unsafe version, all the async calls will reach this
               * point (despite the fact that they're all in the same thread).
               * Uncomment the print() call below to verify. */

              yield simulate_work ();

              /* XXX: uncomment for debugging
              print ("    %3d -> %3d\n", this._counter, this._counter + 1);
              */
              this._counter++;
            }
        }
    }

  public void test_many_concurrent_funcs_safe ()
    {
      _loop = new GLib.MainLoop (null, false);
      this._total_calls = 100;
      this._calls_pending = 0;
      this._counter_increment_pending = false;

      Idle.add (() =>
        {
          for (var i = 0; i < this._total_calls; i++)
            {
              this._calls_pending++;
              locked_increment_safe.begin (increment_handler_safe);
            }

          return false;
        });

      _loop.run ();
    }

  private void increment_handler_safe (GLib.Object? source,
      GLib.AsyncResult result)
    {
      locked_increment_safe.end (result);

      /* calls "ignored" while the first is in-flight still expect the end state
       * when they reach this point */
      assert (this._counter == 1);

      this._calls_pending--;
      if (this._calls_pending == 0)
        {
          print ("\n    final counter value: %d\n", this._counter);
          assert (this._counter == 1);

          this._loop.quit ();
        }
    }

  private async void locked_increment_safe ()
    {
      lock (this._counter)
        {
          if (this._counter < 1 && !this._counter_increment_pending)
            {
              this._counter_increment_pending = true;
              yield simulate_work ();

              /* XXX: uncomment for debugging
              print ("    %3d -> %3d\n", this._counter, this._counter + 1);
              */
              this._counter++;
            }
        }
    }

  private async void simulate_work ()
    {
      Thread.usleep (50 * 1000);
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new AsyncLockingTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
