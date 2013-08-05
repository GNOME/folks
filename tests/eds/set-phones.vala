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

public class SetPhonesTests : EdsTest.TestCase
{
  private IndividualAggregator _aggregator;
  private GLib.MainLoop _main_loop;
  private bool _found_before_update;
  private Collection<string>? _found_phone_type_after_update;

  public SetPhonesTests ()
    {
      base ("SetPhones");

      this.add_test ("setting phones on e-d-s persona", this.test_set_phones);
    }

  void test_set_phones ()
    {
      Gee.HashMap<string, Value?> c1 = new Gee.HashMap<string, Value?> ();
      this._main_loop = new GLib.MainLoop (null, false);
      Value? v;

      this._found_before_update = false;
      this._found_phone_type_after_update = null;

      this.eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      c1.set ("full_name", (owned) v);
      this.eds_backend.add_contact (c1);

      this._test_set_phones_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_before_update);
      assert (this._found_phone_type_after_update != null);
      assert (this._found_phone_type_after_update.size == 1);
      assert (this._found_phone_type_after_update.contains (AbstractFieldDetails.PARAM_TYPE_HOME));
    }

  private async void _test_set_phones_async ()
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

  private void _individuals_changed_cb (
       MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();
      var removed = changes.get_keys ();

      foreach (Individual i in added)
        {
          assert (i != null);

          var name = (Folks.NameDetails) i;

          if (name.full_name == "bernie h. innocenti")
            {
              i.notify["phone-numbers"].connect (this._notify_phones_cb);
              this._found_before_update = true;

              foreach (var p in i.personas)
                {
                  var phones = new HashSet<PhoneFieldDetails> (
                      AbstractFieldDetails<string>.hash_static,
                      AbstractFieldDetails<string>.equal_static);
                  var phone_1 = new PhoneFieldDetails ("1234");
                  phone_1.set_parameter (AbstractFieldDetails.PARAM_TYPE,
                      AbstractFieldDetails.PARAM_TYPE_HOME);
                  phones.add (phone_1);
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
      foreach (var phone_fd in i.phone_numbers)
        {
          /*
           * If EDS is compiled with libphonenumber support, it will
           * add an X-EVOLUTION-E164 parameter with the normalized
           * phone number. We do not know how EDS is compiled and besides,
           * the normalized value also depends on the current locale
           * (the 1 in 1234 is a dialing prefix in the US and gets removed
           * there, but not elsewhere).
           *
           * Therefore we cannot do a full comparison against a
           * PhoneNumberDetails instance with the expected result,
           * because we do not know what that is.
           *
           * Instead just wait for the phone number to show up,
           * then remember the actual type and check that against the expected
           * type after returning from the event loop.
           */
          if (phone_fd.value == "1234")
            {
              this._found_phone_type_after_update = phone_fd.get_parameter_values (AbstractFieldDetails.PARAM_TYPE);
              this._main_loop.quit ();
            }
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new SetPhonesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
