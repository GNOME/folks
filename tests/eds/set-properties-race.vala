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

public class SetPropertiesRaceTests : EdsTest.TestCase
{
  private IndividualAggregator _aggregator;
  private GLib.MainLoop _main_loop;
  private bool _found_before_update;
  private bool _found_after_update;
  private PostalAddressFieldDetails _pa_fd;

  public SetPropertiesRaceTests ()
    {
      base ("SetPropertiesRace");

      this.add_test ("setting postal address on e-d-s persona",
          this.test_set_postal_addresses);
    }

  void test_set_postal_addresses ()
    {
      Gee.HashMap<string, Value?> c1 = new Gee.HashMap<string, Value?> ();
      this._main_loop = new GLib.MainLoop (null, false);
      Value? v;
      var pa = new PostalAddress ("123", "extension", "street",
          "locality", "region", "postal code", "country", "",
          "123");
      this._pa_fd = new PostalAddressFieldDetails (pa);
      this._pa_fd.add_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_OTHER);

      this._found_before_update = false;
      this._found_after_update = false;

      this.eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      c1.set ("full_name", (owned) v);
      this.eds_backend.add_contact (c1);

      this._test_set_postal_addresses_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_before_update);
      assert (this._found_after_update);
    }

  private async void _test_set_postal_addresses_async ()
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
              this._found_before_update = true;

              foreach (var p in i.personas)
                {
                  p.notify["postal-addresses"].connect (
                      this._notify_postal_addresses_cb);
                  var pa_fds = new HashSet<PostalAddressFieldDetails> ();
                  var pa_1 = new PostalAddress ("123", "extension", "street",
                      "locality", "region", "postal code", "country", "format",
                      "123");
                  var pa_fd_1 = new PostalAddressFieldDetails (pa_1);
                  pa_fd_1.add_parameter (AbstractFieldDetails.PARAM_TYPE,
                      AbstractFieldDetails.PARAM_TYPE_OTHER);
                  pa_fds.add (pa_fd_1);
                  ((PostalAddressDetails) p).postal_addresses = pa_fds;
                }
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  private void _notify_postal_addresses_cb (Object persona_obj, ParamSpec ps)
    {
      var p = (Edsf.Persona) persona_obj;

      /* ensure we aren't getting notified before the property set completes */
      assert (p.postal_addresses.size == 1);

      foreach (var pa_fd in p.postal_addresses)
        {
          /* make sure the content is the type expected */
          assert (pa_fd is PostalAddressFieldDetails);
          assert (pa_fd.value is PostalAddress);

          pa_fd.id = this._pa_fd.id;
          if (pa_fd.equal (this._pa_fd))
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

  var tests = new SetPropertiesRaceTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
