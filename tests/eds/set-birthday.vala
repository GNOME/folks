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

using EdsTest;
using Folks;
using Gee;

public class SetBirthdayTests : Folks.TestCase
{
  private EdsTest.Backend _eds_backend;
  private IndividualAggregator _aggregator;
  private GLib.MainLoop _main_loop;
  private bool _found_before_update;
  private bool _found_after_update;

  public SetBirthdayTests ()
    {
      base ("SetBirthday");

      this._eds_backend = new EdsTest.Backend ();

      this.add_test ("setting birthday on an e-d-s persona",
          this.test_set_birthday);
    }

  public override void set_up ()
    {
      this._eds_backend.set_up ();
    }

  public override void tear_down ()
    {
      this._eds_backend.tear_down ();
    }

  void test_set_birthday ()
    {
      Gee.HashMap<string, Value?> c1 = new Gee.HashMap<string, Value?> ();
      this._main_loop = new GLib.MainLoop (null, false);
      Value? v;

      this._found_before_update = false;
      this._found_after_update = false;

      this._eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string ("John McClane");
      c1.set ("full_name", (owned) v);
      this._eds_backend.add_contact (c1);

      this._test_set_birthday_async ();

      Timeout.add_seconds (5, () => {
            this._main_loop.quit ();
            assert_not_reached ();
          });

      this._main_loop.run ();

      assert (this._found_before_update);
      assert (this._found_after_update);
    }

  private async void _test_set_birthday_async ()
    {
      yield this._eds_backend.commit_contacts_to_addressbook ();

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
      foreach (Individual i in added)
        {
          var name = (Folks.NameDetails) i;

          if (name.full_name == "John McClane")
            {
              i.notify["birthday"].connect (this._notify_birthday_cb);
              this._found_before_update = true;

              var dobj = new  DateTime.utc (1980, 1, 1, 0, 0, 0.0);
              foreach (var p in i.personas)
                {
                  ((BirthdayDetails) p).birthday = dobj;
                }
            }
        }

      assert (removed.size == 0);
    }

  private void _notify_birthday_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      var name = (Folks.NameDetails) i;
      var dobj = new  DateTime.utc (1980, 1, 1, 0, 0, 0.0);
      if (name.full_name == "John McClane" &&
          i.birthday != null &&
          i.birthday.equal (dobj))
        {
          this._found_after_update = true;
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new SetBirthdayTests ().get_suite ());

  Test.run ();

  return 0;
}