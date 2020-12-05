/*
 * Copyright (C) 2011 Collabora Ltd.
 *               2014 Canonical Ltd.
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
 * Authors: Renato Araujo Oliveira Filho <renato.filho@canonical.com>
 *
 */

using EdsTest;
using Folks;
using Gee;

public class ChangePhonesTests : EdsTest.TestCase
{
  private IndividualAggregator _aggregator;
  private GLib.MainLoop _main_loop;
  private Gee.HashMap<string, Value?> _c1;
  private bool _found_before_update;
  private bool _found_after_update;

  public ChangePhonesTests ()
    {
      base ("ChangePhones");

      this.add_test ("changing phones on e-d-s persona", this.test_change_phones);
    }

  void test_change_phones ()
    {
      this._c1 = new Gee.HashMap<string, Value?> ();
      this._main_loop = new GLib.MainLoop (null, false);
      Value? v;

      this._found_before_update = false;
      this._found_after_update = false;

      this.eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      this._c1.set ("full_name", (owned) v);

      v = Value (typeof (string));
      v.set_string ("754-3010");
      this._c1.set ("car_phone", (owned) v);
      v = Value (typeof (string));
      v.set_string ("636-4018");
      this._c1.set ("company_phone", (owned) v);
      v = Value (typeof (string));
      v.set_string ("754-4018");
      this._c1.set ("home_phone", (owned) v);
      this.eds_backend.add_contact (this._c1);

      this._test_change_phones_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop, 10);

      assert (this._found_before_update);
      assert (this._found_after_update);
    }

  private async void _test_change_phones_async ()
    {
      yield this.eds_backend.commit_contacts_to_addressbook ();

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

  private async void _update_contact ()
    {
      Gee.HashMap<string, Value?> updated_data =
        new Gee.HashMap<string, Value?> ();
      Value? v;

      v = Value (typeof (string));
      v.set_string ("(541) 754-4018");

      updated_data.set("home_phone", (owned) v);
      yield this.eds_backend.update_contact (0, updated_data);
    }

  private void _notify_phones_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      foreach (var phone_fd in i.phone_numbers)
        {
          foreach (var t in phone_fd.get_parameter_values (
              AbstractFieldDetails.PARAM_TYPE))
            {
              if ((t == AbstractFieldDetails.PARAM_TYPE_HOME) &&
                  (phone_fd.value == "(541) 754-4018") &&
                  (this._found_before_update))
                {
                  this._found_after_update = true;
                  this._main_loop.quit ();
                }
            }
        }
    }

  private void _individuals_changed_cb (
       MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();
      var removed = changes.get_keys ();

      foreach (Individual i in added)
        {
          assert (i != null);

          var phones = (Folks.PhoneDetails) i;

          foreach (var phone_fd in phones.phone_numbers)
            {
              foreach (var t in phone_fd.get_parameter_values (
                  AbstractFieldDetails.PARAM_TYPE))
                {
                  if ((t == AbstractFieldDetails.PARAM_TYPE_HOME) &&
                      (phone_fd.value == "754-4018") &&
                      (!this._found_before_update))
                    {
                      i.notify["phone-numbers"].connect (this._notify_phones_cb);
                      this._found_before_update = true;
                      this._update_contact.begin ();
                    }
                }
            }
        }
      assert (removed.size == 1);
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new ChangePhonesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
