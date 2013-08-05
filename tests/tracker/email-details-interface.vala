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

public class EmailDetailsInterfaceTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private int _num_emails;
  private bool _found_email_1;
  private bool _found_email_2;

  public EmailDetailsInterfaceTests ()
    {
      base ("EmailDetailsInterfaceTests");

      this.add_test ("test email details interface",
          this.test_email_details_interface);
    }

  public void test_email_details_interface ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, "persona #1");
      c1.set (Trf.OntologyDefs.NCO_EMAIL_PROP,
          "test1@example.org,test2@example.org");
      ((!) this.tracker_backend).add_contact (c1);

      ((!) this.tracker_backend).set_up ();

      this._num_emails = 0;
      this._found_email_1 = false;
      this._found_email_2 = false;

      this._test_email_details_interface_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._num_emails == 2);
      assert (this._found_email_1 == true);
      assert (this._found_email_2 == true);
    }

  private async void _test_email_details_interface_async ()
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

          string full_name = i.full_name;
          if (full_name != null)
            {
              foreach (var email in i.email_addresses)
                {
                  if (email.value == "test1@example.org")
                    {
                      this._found_email_1 = true;
                      this._num_emails++;
                    }
                  else if (email.value == "test2@example.org")
                    {
                      this._found_email_2 = true;
                      this._num_emails++;
                    }
                }
            }
        }

        if (this._found_email_1 &&
            this._found_email_2 &&
            this._num_emails == 2)
          this._main_loop.quit ();

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

  var tests = new EmailDetailsInterfaceTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
