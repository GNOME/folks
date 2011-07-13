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

public class SetEmailsTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private string _email_1;
  private string _email_2;
  private bool _email_1_found;
  private bool _email_2_found;

  public SetEmailsTests ()
    {
      base ("SetEmailsTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test setting emails ", this.test_set_emails);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_set_emails ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._persona_fullname = "persona #1";
      this._email_1 = "email-1@example.org";
      this._email_2 = "email-2@example.org";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      this._tracker_backend.add_contact (c1);

      this._tracker_backend.set_up ();

      this._email_1_found = false;
      this._email_2_found = false;

      this._test_set_emails_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._email_1_found);
      assert (this._email_2_found);

     this._tracker_backend.tear_down ();
    }

  private async void _test_set_emails_async ()
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
              i.notify["email-addresses"].connect (this._notify_emails_cb);

              var emails = new HashSet<FieldDetails> (
                  (GLib.HashFunc) FieldDetails.hash,
                  (GLib.EqualFunc) FieldDetails.equal);
              var p1 = new FieldDetails (this._email_1);
              emails.add (p1);
              var p2 = new FieldDetails (this._email_2);
              emails.add (p2);

              foreach (var p in i.personas)
                {
                  ((EmailDetails) p).email_addresses = emails;
                }
            }
        }

      assert (removed.size == 0);
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

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new SetEmailsTests ().get_suite ());

  Test.run ();

  return 0;
}
