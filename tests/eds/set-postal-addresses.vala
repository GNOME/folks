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

public class SetPostalAddressesTests : Folks.TestCase
{
  private EdsTest.Backend _eds_backend;
  private IndividualAggregator _aggregator;
  private GLib.MainLoop _main_loop;
  private bool _found_before_update;
  private bool _found_after_update;
  private PostalAddress _postal;

  public SetPostalAddressesTests ()
    {
      base ("SetPostalAddresses");

      this._eds_backend = new EdsTest.Backend ();

      this.add_test ("setting postal addresss on e-d-s persona",
          this.test_set_postal_addresses);
    }

  public override void set_up ()
    {
      this._eds_backend.set_up ();
    }

  public override void tear_down ()
    {
      this._eds_backend.tear_down ();
    }

  void test_set_postal_addresses ()
    {
      Gee.HashMap<string, Value?> c1 = new Gee.HashMap<string, Value?> ();
      this._main_loop = new GLib.MainLoop (null, false);
      Value? v;
      var types = new HashSet<string> ();
      types.add ("address_other");
      this._postal = new PostalAddress ("123", "extension", "street",
          "locality", "region", "postal code", "country", "",
          types, "123");

      this._found_before_update = false;
      this._found_after_update = false;

      this._eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      c1.set ("full_name", (owned) v);
      this._eds_backend.add_contact (c1);

      this._test_set_postal_addresses_async ();

      Timeout.add_seconds (5, () => {
            this._main_loop.quit ();
            assert_not_reached ();
          });

      this._main_loop.run ();

      assert (this._found_before_update);
      assert (this._found_after_update);
    }

  private async void _test_set_postal_addresses_async ()
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

          if (name.full_name == "bernie h. innocenti")
            {
              i.notify["postal-addresses"].connect (
                  this._notify_postal_addresses_cb);
              this._found_before_update = true;

              foreach (var p in i.personas)
                {
                  var addresses = new HashSet<PostalAddress> ();
                  var types = new HashSet<string> ();
                  types.add ("address_other");
                  var addr1 = new PostalAddress ("123", "extension", "street",
                      "locality", "region", "postal code", "country", "format",
                      types, "123");
                  addresses.add (addr1);
                  ((PostalAddressDetails) p).postal_addresses = addresses;
                }
            }
        }

      assert (removed.size == 0);
    }

  private void _notify_postal_addresses_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      foreach (var p in i.postal_addresses)
        {
          p.uid = this._postal.uid;
          if (p.equal (this._postal))
            {
              this._found_after_update = true;
              this._main_loop.quit ();
            }
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new SetPostalAddressesTests ().get_suite ());

  Test.run ();

  return 0;
}
