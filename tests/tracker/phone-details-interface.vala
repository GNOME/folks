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

public class PhoneDetailsInterfaceTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private TrackerTest.Backend _tracker_backend;
  private int _num_phones = 0;
  private bool _found_phone_1 = false;
  private bool _found_phone_2 = false;

  public PhoneDetailsInterfaceTests ()
    {
      base ("PhoneDetailsInterfaceTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test phone details interface",
          this.test_phone_details_interface);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_phone_details_interface ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, "persona #1");
      c1.set (Trf.OntologyDefs.NCO_PHONE_PROP, "12345,54321");
      this._tracker_backend.add_contact (c1);

      this._tracker_backend.set_up ();

      this._num_phones = 0;
      this._found_phone_1 = false;
      this._found_phone_2 = false;

      this._test_phone_details_interface_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._num_phones == 2);
      assert (this._found_phone_1 == true);
      assert (this._found_phone_2 == true);

      this._tracker_backend.tear_down ();
    }

  private async void _test_phone_details_interface_async ()
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
          string full_name = i.full_name;
          if (full_name != null)
            {
              foreach (var phone in i.phone_numbers)
              {
                if (phone.value == "12345")
                  {
                    this._found_phone_1 = true;
                    this._num_phones++;
                  }
                else if (phone.value == "54321")
                  {
                    this._found_phone_2 = true;
                    this._num_phones++;
                  }
              }
            }
        }

      assert (removed.size == 0);

      if (this._num_phones == 2 &&
          this._found_phone_1 == true &&
          this._found_phone_2 == true)
        this._main_loop.quit ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new PhoneDetailsInterfaceTests ().get_suite ());

  Test.run ();

  return 0;
}
