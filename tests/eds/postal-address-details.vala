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

using Folks;
using Gee;

public class PostalAddressDetailsTests : EdsTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _pobox = "12345";
  private string _locality = "example locality";
  private string _postalcode = "example postalcode";
  private string _street = "example street";
  private string _extended = "example extended address";
  private string _country = "example country";
  private string _region = "example region";
  private PostalAddressFieldDetails _postal_address;
  private bool _found_postal_address;
  private string _fullname;

  public PostalAddressDetailsTests ()
    {
      base ("PostalAddressDetailsTests");

      this.add_test ("test postal address details interface",
          this.test_postal_address_details_interface);
    }

  public void test_postal_address_details_interface ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, Value?> c1 = new Gee.HashMap<string, Value?> ();
      this._fullname = "persona #1";
      Value? v;

      var pa = new PostalAddress (
           this._pobox,
           this._extended,
           this._street,
           this._locality,
           this._region,
           this._postalcode,
           this._country,
           null, "eds_id");
      this._postal_address = new PostalAddressFieldDetails (pa);
      this._postal_address.add_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_HOME);

      v = Value (typeof (string));
      v.set_string (this._fullname);
      c1.set ("full_name", (owned) v);
      var pa_copy = new PostalAddress (
           this._pobox,
           this._extended,
           this._street,
           this._locality,
           this._region,
           this._postalcode,
           this._country,
           null, "eds_id");
      var pa_fd_copy = new PostalAddressFieldDetails (pa_copy);
      pa_fd_copy.add_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_HOME);
      v = Value (typeof (PostalAddressFieldDetails));
      v.set_object (pa_fd_copy);
      /* corresponds to address of type "home" */
      c1.set (Edsf.Persona.address_fields[0], (owned) v);

      this.eds_backend.add_contact (c1);

      this._found_postal_address = false;

      this._test_postal_address_details_interface_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_postal_address == true);
    }

  private async void _test_postal_address_details_interface_async ()
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

      foreach (var i in added)
        {
          assert (i != null);

          if (i.full_name == this._fullname)
            {
              foreach (var pa_fd in i.postal_addresses)
              {
                /* We copy the uid - we don't know it.
                 * Although we could get it from the 1st
                 * personas iid; there is no real need.
                 */
                this._postal_address.id = pa_fd.id;

                if (pa_fd.equal (this._postal_address))
                  {
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

  var tests = new PostalAddressDetailsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
