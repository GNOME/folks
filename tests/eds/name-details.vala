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

public class NameDetailsTests : EdsTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private int _names_count;
  private Gee.HashMap<string, Value?> _c1;
  private Gee.HashMap<string, Value?> _c2;

  public NameDetailsTests ()
    {
      base ("NameDetails");

      this.add_test ("name details interface", this.test_names);
    }

  public void test_names ()
    {
      this._c1 = new Gee.HashMap<string, Value?> ();
      this._c2 = new Gee.HashMap<string, Value?> ();
      this._names_count = 0;
      this._main_loop = new GLib.MainLoop (null, false);
      Value? v;

      this.eds_backend.reset ();

      /* FIXME: passing the EContactName would be better */
      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      this._c1.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("bernie");
      this._c1.set ("nickname", (owned) v);
      v = Value (typeof (string));
      v.set_string ("Innocenti");
      this._c1.set ("contact_name_family", (owned) v);
      v = Value (typeof (string));
      v.set_string ("Bernardo");
      this._c1.set ("contact_name_given", (owned) v);
      v = Value (typeof (string));
      v.set_string ("H.");
      this._c1.set ("contact_name_additional", (owned) v);
      v = Value (typeof (string));
      v.set_string ("Mr.");
      this._c1.set ("contact_name_prefixes", (owned) v);
      v = Value (typeof (string));
      v.set_string ("(sysadmin FSF)");
      this._c1.set ("contact_name_suffixes", (owned) v);
      this.eds_backend.add_contact (this._c1);

      v = Value (typeof (string));
      v.set_string ("richard m. stallman");
      this._c2.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("Stallman");
      this._c2.set ("contact_name_family", (owned) v);
      v = Value (typeof (string));
      v.set_string ("Richard M.");
      this._c2.set ("contact_name_given", (owned) v);
      this.eds_backend.add_contact (this._c2);

      this._test_names_async.begin ();

      TestUtils.loop_run_with_non_fatal_timeout (this._main_loop, 5);

      assert (this._names_count == 2);
      assert (this._c1.size == 0);
      assert (this._c2.size == 0);
    }

  private async void _test_names_async ()
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

          string s;

          assert (i.personas.size == 1);

          var name = (Folks.NameDetails) i;

          if (i.full_name == "bernie h. innocenti")
            {
              assert (name.structured_name.is_empty () == false);

              s = this._c1.get ("full_name").get_string ();
              assert (name.full_name == s);
              this._c1.unset ("full_name");

              s = this._c1.get ("nickname").get_string ();
              assert (name.nickname == s);
              this._c1.unset ("nickname");

              s = this._c1.get ("contact_name_family").get_string ();
              assert (name.structured_name.family_name == s);
              this._c1.unset ("contact_name_family");

              s = this._c1.get ("contact_name_given").get_string ();
              assert (name.structured_name.given_name == s);
              this._c1.unset ("contact_name_given");

              s = this._c1.get ("contact_name_additional").get_string ();
              assert (name.structured_name.additional_names == s);
              this._c1.unset ("contact_name_additional");

              s = this._c1.get ("contact_name_prefixes").get_string ();
              assert (name.structured_name.prefixes == s);
              this._c1.unset ("contact_name_prefixes");

              s = this._c1.get ("contact_name_suffixes").get_string ();
              assert (name.structured_name.suffixes == s);
              this._c1.unset ("contact_name_suffixes");
            }
          else if (i.full_name == "richard m. stallman")
            {
              assert (name.structured_name.is_empty () == false);

              s = this._c2.get ("full_name").get_string ();
              assert (name.full_name == s);
              this._c2.unset ("full_name");

              s = this._c2.get ("contact_name_family").get_string ();
              assert (name.structured_name.family_name == s);
              this._c2.unset ("contact_name_family");

              s = this._c2.get ("contact_name_given").get_string ();
              assert (name.structured_name.given_name == s);
              this._c2.unset ("contact_name_given");
            }

          this._names_count++;
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }

        if (this._c1.size == 0 &&
            this._c2.size == 0)
          {
            this._main_loop.quit ();
          }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new NameDetailsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
