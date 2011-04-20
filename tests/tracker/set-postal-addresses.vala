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

public class SetPostalAddressesTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private bool _postal_address_found;
  private PostalAddress _address;

  public SetPostalAddressesTests ()
    {
      base ("SetPostalAddressesTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test setting postal addresses ",
          this.test_set_postal_addresses);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_set_postal_addresses ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._persona_fullname = "persona #1";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      this._tracker_backend.add_contact (c1);

      var types =  new HashSet<string> ();
      this._address = new PostalAddress (null, null, null, null, null,
          null, null, null, types, null);
      this._address.po_box = "12345";
      this._address.locality = "locality";
      this._address.postal_code = "code";
      this._address.street = "some street";
      this._address.extension = "some extension";
      this._address.country = "some country";
      this._address.region = "some region";

      this._tracker_backend.set_up ();

      this._postal_address_found = false;

      this._test_set_postal_addresses_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._postal_address_found);

     this._tracker_backend.tear_down ();
    }

  private async void _test_set_postal_addresses_async ()
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
              i.notify["postal-addresses"].connect (this._notify_postal_cb);

              var types =  new HashSet<string> ();
              var addresses = new HashSet<PostalAddress> ();
              var pa = new Folks.PostalAddress (null, null, null, null, null,
                null, null, null, types, null);
              pa.po_box = this._address.po_box;
              pa.locality = this._address.locality;
              pa.postal_code =this._address.postal_code;
              pa.street = this._address.street;
              pa.extension = this._address.extension;
              pa.country = this._address.country;
              pa.region  = this._address.region;

              addresses.add (pa);

              foreach (var p in i.personas)
                {
                  ((PostalAddressDetails) p).postal_addresses = addresses;
                }
            }
        }

      assert (removed.size == 0);
    }

  private void _notify_postal_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      if (i.full_name == this._persona_fullname)
        {
          foreach (var p in i.postal_addresses)
            {
              /* we don't care if UIDs differ for this test */
              this._address.uid = p.uid;
              if (p.equal (this._address))
                {
                  this._postal_address_found = true;
                  this._main_loop.quit ();
                }
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
