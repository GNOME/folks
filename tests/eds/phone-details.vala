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

public class PhoneDetailsTests : EdsTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private int _phones_count;
  private HashSet<string> _phone_types;
  private Gee.HashMap<string, Value?> _c1;
  private Gee.HashMap<string, Value?> _c2;

  public PhoneDetailsTests ()
    {
      base ("PhoneDetails");

      this.add_test ("phone details interface", this.test_phone_numbers);
    }

  public void test_phone_numbers ()
    {
      this._phones_count = 0;
      this._phone_types = new HashSet<string> ();
      this._c1 = new Gee.HashMap<string, Value?> ();
      this._c2 = new Gee.HashMap<string, Value?> ();
      this._main_loop = new GLib.MainLoop (null, false);
      Value? v;

      this.eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      this._c1.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("123");
      this._c1.set ("car_phone", (owned) v);
      v = Value (typeof (string));
      v.set_string ("1234");
      this._c1.set ("company_phone", (owned) v);
      v = Value (typeof (string));
      v.set_string ("12345");
      this._c1.set ("home_phone", (owned) v);
      this.eds_backend.add_contact (this._c1);

      v = Value (typeof (string));
      v.set_string ("richard m. stallman");
      this._c2.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("54321");
      this._c2.set ("car_phone", (owned) v);
      v = Value (typeof (string));
      v.set_string ("4321");
      this._c2.set ("company_phone", (owned) v);
      v = Value (typeof (string));
      v.set_string ("321");
      this._c2.set ("home_phone", (owned) v);
      this.eds_backend.add_contact (this._c2);

      this._test_phone_numbers_async.begin ();

      TestUtils.loop_run_with_non_fatal_timeout (this._main_loop, 5);

      assert (this._phones_count == 6);
      assert (this._phone_types.size == 3);
      assert (this._c1.size == 0);
      assert (this._c2.size == 0);

      foreach (var pt in this._phone_types)
        {
          assert(pt in Edsf.Persona.phone_fields);
        }
   }

  private async void _test_phone_numbers_async ()
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

          unowned Gee.HashMap<string, Value?> contact = null;
          assert (i.personas.size == 1);

          if (i.full_name == "bernie h. innocenti")
            {
              contact = this._c1;
            }
          else if (i.full_name == "richard m. stallman")
            {
              contact = this._c2;
            }

          if (contact == null)
            {
              continue;
            }

          contact.unset ("full_name");
          var phone_numbers = (Folks.PhoneDetails) i;
          foreach (var phone_fd in phone_numbers.phone_numbers)
            {
              this._phones_count++;
              foreach (var t in phone_fd.get_parameter_values (
                  AbstractFieldDetails.PARAM_TYPE))
                {
                  string? v = null;

                  if (t == "car")
                    {
                      v = "car_phone";
                    }
                  else if (t == AbstractFieldDetails.PARAM_TYPE_HOME)
                    {
                      v = "home_phone";
                    }
                  else if (t == "x-evolution-company")
                    {
                      v = "company_phone";
                    }

                  if (v == null)
                    {
                      continue;
                    }

                  this._phone_types.add (v);
                  assert (contact.get (v).get_string () == phone_fd.value);
                  contact.unset (v);
                }
            }
        }

        if (this._phones_count == 6)
          {
            this._main_loop.quit ();
          }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new PhoneDetailsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
