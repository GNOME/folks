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

public class SetIMAddressesTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private GLib.List<string> _addresses =
    new GLib.List<string> ();
  private bool _initial_individual_found;

  public SetIMAddressesTests ()
    {
      base ("SetIMAddressesTests");

      this.add_test ("test setting im_addresses ", this.test_set_im_addresses);
    }

  public void test_set_im_addresses ()
    {
      this._initial_individual_found = false;
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 =
        new Gee.HashMap<string, string> ();
      this._persona_fullname = "persona #1";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      ((!) this.tracker_backend).add_contact (c1);

      this._addresses.prepend ("one@example.org");
      this._addresses.prepend ("two@example.org");
      this._addresses.prepend ("three@example.org");
      this._addresses.prepend ("four@example.org");

      ((!) this.tracker_backend).set_up ();

      this._test_set_im_addresses_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._initial_individual_found);
      assert (this._addresses.length () == 0);
    }

  private async void _test_set_im_addresses_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = IndividualAggregator.dup ();
      this._aggregator.individuals_changed_detailed.connect
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

  private void _individuals_changed_cb (
       MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();

      foreach (var i in added)
        {
          assert (i != null);

          if (i.full_name != this._persona_fullname)
            continue;

          if (!this._initial_individual_found)
            {
              this._initial_individual_found = true;
              i.notify["im-addresses"].connect (this._notify_im_addresses_cb);

              var im_addresses = new HashMultiMap<string, ImFieldDetails> (
                  null, null, AbstractFieldDetails<string>.hash_static,
                  AbstractFieldDetails<string>.equal_static);

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
          else
            {
              i.notify["im-addresses"].connect (this._notify_im_addresses_cb);
              this._check_im_addresses (i);
            }
        }
    }

  private void _notify_im_addresses_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      this._check_im_addresses (i);
    }

  private void _check_im_addresses (Individual i)
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

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new SetIMAddressesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
