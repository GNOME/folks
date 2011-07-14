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
 * Authors: Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *
 */

using Tracker.Sparql;
using TrackerTest;
using Folks;
using Gee;

public class SetIMAddressesTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private GLib.List<string> _addresses =
    new GLib.List<string> ();

  public SetIMAddressesTests ()
    {
      base ("SetIMAddressesTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test setting im_addresses ", this.test_set_im_addresses);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_set_im_addresses ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 =
        new Gee.HashMap<string, string> ();
      this._persona_fullname = "persona #1";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      this._tracker_backend.add_contact (c1);

      this._addresses.prepend ("one@example.org");
      this._addresses.prepend ("two@example.org");
      this._addresses.prepend ("three@example.org");
      this._addresses.prepend ("four@example.org");

      this._tracker_backend.set_up ();

      this._test_set_im_addresses_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._addresses.length () == 0);

      this._tracker_backend.tear_down ();
    }

  private async void _test_set_im_addresses_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = new IndividualAggregator ();
      this._aggregator.individuals_changed.connect
          (this._individuals_changed_cb);
      try
        {
          yield this._aggregator.prepare ();
        }
        catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }
    }

 private void _individuals_changed_cb
      (Set<Individual> added,
       Set<Individual> removed,
       string? message,
       Persona? actor,
       GroupDetails.ChangeReason reason)
    {
      foreach (var i in added)
        {
          if (i.full_name == this._persona_fullname)
            {
              i.notify["im-addresses"].connect (this._notify_im_addresses_cb);

              var im_addresses = new HashMultiMap<string, ImFieldDetails> (
                  null, null,
                  (GLib.HashFunc)ImFieldDetails.hash,
                  (GLib.EqualFunc) ImFieldDetails.equal);

              im_addresses.set ("aim", new ImFieldDetails ("one@example.org"));
              im_addresses.set ("aim", new ImFieldDetails ("two@example.org"));

              im_addresses.set ("yahoo",
                  new ImFieldDetails ("three@example.org"));
              im_addresses.set ("yahoo",
                  new ImFieldDetails ("four@example.org"));

              foreach (var p in i.personas)
                {
                  ((ImDetails) p).im_addresses = im_addresses;
                }
            }
        }

      assert (removed.size == 0);
    }

  private void _notify_im_addresses_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      if (i.full_name == this._persona_fullname)
        {
          foreach (var proto in i.im_addresses.get_keys ())
            {
              var im_fds = i.im_addresses.get (proto);
              foreach (var im_fd in im_fds)
                {
                  foreach (unowned string my_a in this._addresses)
                    {
                      if (my_a == im_fd.value)
                        {
                          this._addresses.remove (my_a);
                          break;
                        }
                    }
                }
            }

            if (this._addresses.length () == 0)
            {
              this._main_loop.quit ();
            }
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new SetIMAddressesTests ().get_suite ());

  Test.run ();

  return 0;
}
