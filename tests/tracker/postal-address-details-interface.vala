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

public class PostalAddressDetailsInterfaceTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
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
  private PostalAddressFieldDetails _postal_address_fd;
  private bool _found_postal_address;
  private string _fullname;

  public PostalAddressDetailsInterfaceTests ()
    {
      base ("PostalAddressDetailsInterfaceTests");

      this.add_test ("test postal address details interface",
          this.test_postal_address_details_interface);
    }

  public void test_postal_address_details_interface ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._fullname = "persona #1";
      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._fullname);

      var pa = new PostalAddress (
           this._pobox,
           this._extended,
           this._street,
           this._locality,
           this._region,
           this._postalcode,
           this._country,
           null, "tracker_id");
      this._postal_address_fd = new PostalAddressFieldDetails (pa);

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
      ((!) this.tracker_backend).add_contact (c1);
      ((!) this.tracker_backend).set_up ();

      this._found_postal_address = false;

      this._test_postal_address_details_interface_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_postal_address == true);
    }

  private async void _test_postal_address_details_interface_async ()
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
      var removed = changes.get_keys ();

      foreach (var i in added)
        {
          assert (i != null);

          if (i.full_name == this._fullname)
            {
              foreach (var pafd in i.postal_addresses)
              {
                /* We copy the tracker_id - we don't know it.
                 * Although we could get it from the 1st
                 * personas iid; there is no real need.
                 */
                this._postal_address_fd.id = pafd.id;

                if (pafd.value.equal (this._postal_address_fd.value))
                  {
                    /* Ensure that setting the postal address uid directly
                     * (which is deprecated) is equivalent to setting the id on
                     * a PostalAddressFieldDetails directly */
                    var pa_2 = new PostalAddress (
                        this._postal_address_fd.value.po_box,
                        this._postal_address_fd.value.extension,
                        this._postal_address_fd.value.street,
                        this._postal_address_fd.value.locality,
                        this._postal_address_fd.value.region,
                        this._postal_address_fd.value.postal_code,
                        this._postal_address_fd.value.country,
                        null,
                        pafd.id);
                    var pa_fd_2 = new PostalAddressFieldDetails (pa_2);
                    assert (pafd.equal (pa_fd_2));
                    assert (pafd.id == pa_fd_2.id);

                    this._found_postal_address = true;
                    this._main_loop.quit ();
                  }
              }
            }
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

  var tests = new PostalAddressDetailsInterfaceTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
