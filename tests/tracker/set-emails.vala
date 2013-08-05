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

public class SetEmailsTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private string _email_1;
  private string _email_2;
  private bool _email_1_found;
  private bool _email_2_found;

  public SetEmailsTests ()
    {
      base ("SetEmailsTests");

      this.add_test ("test setting emails ", this.test_set_emails);
    }

  public void test_set_emails ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._persona_fullname = "persona #1";
      this._email_1 = "email-1@example.org";
      this._email_2 = "email-2@example.org";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      ((!) this.tracker_backend).add_contact (c1);

      ((!) this.tracker_backend).set_up ();

      this._email_1_found = false;
      this._email_2_found = false;

      this._test_set_emails_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._email_1_found);
      assert (this._email_2_found);
    }

  private async void _test_set_emails_async ()
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

          if (i.full_name == this._persona_fullname)
            {
              i.notify["email-addresses"].connect (this._notify_emails_cb);

              var emails = new HashSet<EmailFieldDetails> (
                  AbstractFieldDetails<string>.hash_static,
                  AbstractFieldDetails<string>.equal_static);
              var p1 = new EmailFieldDetails (this._email_1);
              emails.add (p1);
              var p2 = new EmailFieldDetails (this._email_2);
              emails.add (p2);

              foreach (var p in i.personas)
                {
                  ((EmailDetails) p).email_addresses = emails;
                }
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  private void _notify_emails_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      if (i.full_name == this._persona_fullname)
        {
          foreach (var p in i.email_addresses)
            {
              if (p.value == this._email_1)
                this._email_1_found = true;
              else if (p.value == this._email_2)
                this._email_2_found = true;
            }
        }

      if (this._email_1_found && this._email_2_found)
        {
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new SetEmailsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
