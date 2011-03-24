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

public class PostalAddressDetailsInterfaceTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private TrackerTest.Backend _tracker_backend;
  private string _pobox = "12345";
  private string _district = "example district";
  private string _county = "example country";
  private string _locality = "example locality";
  private string _postalcode = "example postalcode";
  private string _street = "example street";
  private string _address = "example address";
  private string _extended = "example extended address";
  private string _country = "example country";
  private string _region = "example region";
  private PostalAddress _postal_address;
  private bool _found_postal_address;
  private string _fullname;

  public PostalAddressDetailsInterfaceTests ()
    {
      base ("PostalAddressDetailsInterfaceTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test postal address details interface",
          this.test_postal_address_details_interface);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_postal_address_details_interface ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._fullname = "persona #1";
      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._fullname);

      GLib.List<string> types = new GLib.List<string> ();
      this._postal_address = new PostalAddress (
           this._pobox,
           this._extended,
           this._street,
           this._locality,
           this._region,
           this._postalcode,
           this._country,
           null, types, "tracker_id");

      // nco:pobox, nco:district, nco:county, nco:locality, nco:postalcode,
      // nco:streetAddress
      // nco:addressLocation, nco:extendedAddress, nco:country, nco:region
      string postal_info = this._pobox + ":";
      postal_info += this._district + ":";
      postal_info += this._county + ":";
      postal_info += this._locality  + ":";
      postal_info += this._postalcode  + ":";
      postal_info += this._street  + ":";
      postal_info += this._address  + ":";
      postal_info += this._extended  + ":";
      postal_info += this._country  + ":";
      postal_info += this._region;

      c1.set (Trf.OntologyDefs.NCO_POSTAL_ADDRESS, postal_info);
      this._tracker_backend.add_contact (c1);
      this._tracker_backend.set_up ();

      this._found_postal_address = false;

      this._test_postal_address_details_interface_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._found_postal_address == true);

      this._tracker_backend.tear_down ();
    }

  private async void _test_postal_address_details_interface_async ()
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
          if (i.full_name == this._fullname)
            {
              foreach (var p in i.postal_addresses)
              {
                /* We copy the tracker_id - we don't know it.
                 * Although we could get it from the 1st
                 * personas iid; there is no real need.
                 */
                this._postal_address.uid = p.uid;

                if (p.equal (this._postal_address))
                  {
                    this._found_postal_address = true;
                    this._main_loop.quit ();
                  }
              }
            }
        }

      assert (removed.size == 0);
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new PostalAddressDetailsInterfaceTests ().get_suite ());

  Test.run ();

  return 0;
}
