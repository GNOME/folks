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

public class SetPhonesTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private string _phone_1;
  private string _phone_2;
  private bool _phone_1_found;
  private bool _phone_2_found;

  public SetPhonesTests ()
    {
      base ("SetPhonesTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test setting phones ", this.test_set_phones);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_set_phones ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._persona_fullname = "persona #1";
      this._phone_1 = "12345";
      this._phone_2 = "54321";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      this._tracker_backend.add_contact (c1);

      this._tracker_backend.set_up ();

      this._phone_1_found = false;
      this._phone_2_found = false;

      this._test_set_phones_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._phone_1_found);
      assert (this._phone_2_found);

     this._tracker_backend.tear_down ();
    }

  private async void _test_set_phones_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = new IndividualAggregator ();
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
      var removed = changes.get_keys ();

      foreach (var i in added)
        {
          assert (i != null);

          if (i.full_name == this._persona_fullname)
            {
              i.notify["phone-numbers"].connect (this._notify_phones_cb);

              var phones = new HashSet<PhoneFieldDetails> (
                   AbstractFieldDetails<string>.hash_static,
                   AbstractFieldDetails<string>.equal_static);

              var p1 = new PhoneFieldDetails (this._phone_1);
              phones.add (p1);
              var p2 = new PhoneFieldDetails (this._phone_2);
              phones.add (p2);

              foreach (var p in i.personas)
                {
                  ((PhoneDetails) p).phone_numbers = phones;
                }
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  private void _notify_phones_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      if (i.full_name == this._persona_fullname)
        {
          foreach (var p in i.phone_numbers)
            {
              if (p.equal (new PhoneFieldDetails (this._phone_1)))
                this._phone_1_found = true;
              else if (p.equal (new PhoneFieldDetails (this._phone_2)))
                this._phone_2_found = true;
            }
        }

      if (this._phone_1_found && this._phone_2_found)
        {
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new SetPhonesTests ().get_suite ());

  Test.run ();

  return 0;
}
