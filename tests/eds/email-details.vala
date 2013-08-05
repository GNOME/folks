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

public class EmailDetailsTests : EdsTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private int _email_count;
  private HashSet<string> _email_types;
  private Gee.HashMap<string, Value?> _c1;
  private Gee.HashMap<string, Value?> _c2;
  private Gee.HashMap<string, Value?> _c3;

  public EmailDetailsTests ()
    {
      base ("EmailDetails");

      this.add_test ("email details interface", this.test_email_details);
    }

  public void test_email_details ()
    {
      this._email_count = 0;
      this._email_types = new HashSet<string> ();
      this._c1 = new Gee.HashMap<string, Value?> ();
      this._c2 = new Gee.HashMap<string, Value?> ();
      this._c3 = new Gee.HashMap<string, Value?> ();
      this._main_loop = new GLib.MainLoop (null, false);
      Value? v;

      this.eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      this._c1.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("bernie@example.org");
      this._c1.set (Edsf.Persona.email_fields[0], (owned) v);
      v = Value (typeof (string));
      v.set_string ("bernie.innocenti@example.org");
      this._c1.set (Edsf.Persona.email_fields[1], (owned) v);
      this.eds_backend.add_contact (this._c1);

      v = Value (typeof (string));
      v.set_string ("richard m. stallman");
      this._c2.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("rms@example.org");
      this._c2.set (Edsf.Persona.email_fields[0], (owned) v);
      v = Value (typeof (string));
      v.set_string ("rms.1@example.org");
      this._c2.set (Edsf.Persona.email_fields[1], (owned) v);
      this.eds_backend.add_contact (this._c2);

      v = Value (typeof (string));
      v.set_string ("foo bar");
      this._c3.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("foo@example.org");
      this._c3.set (Edsf.Persona.email_fields[0], (owned) v);
      v = Value (typeof (string));
      v.set_string ("foo.bar@example.org");
      this._c3.set (Edsf.Persona.email_fields[1], (owned) v);
      this.eds_backend.add_contact (this._c3);

      this._test_email_details_async.begin ();

      TestUtils.loop_run_with_non_fatal_timeout (this._main_loop, 5);

      assert (this._email_count == 6);
      assert (this._email_types.size == 1);
      assert (this._c1.size == 0);
      assert (this._c2.size == 0);
      assert (this._c3.size == 0);

      foreach (var pt in this._email_types)
        {
          assert (pt == AbstractFieldDetails.PARAM_TYPE_OTHER);
        }
    }

  private async void _test_email_details_async ()
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
          else if (i.full_name == "foo bar")
            {
              contact = this._c3;
            }

          if (contact == null)
            {
              continue;
            }

          contact.unset ("full_name");
          var email_owner = (Folks.EmailDetails) i;
          foreach (var e in email_owner.email_addresses)
            {
              this._email_count++;

              bool found = false;
              for (int j = 0; j < 2; j++) {
                  var v = Edsf.Persona.email_fields[j];
                  if (contact.get (v) != null &&
                      contact.get (v).get_string () == e.value) {
                      found = true;
                      contact.unset (v);
                  }
              }
              assert (found);
              foreach (var v in e.get_parameter_values (AbstractFieldDetails.PARAM_TYPE))
                {
                  this._email_types.add (v);
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

  var tests = new EmailDetailsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
