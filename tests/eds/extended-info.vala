/*
 * Copyright (C) 2013 Collabora Ltd.
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
 * Authors: Rodrigo Moya <rodrigo.moya@collabora.co.uk>
 *
 */

using EdsTest;
using Folks;
using Gee;

public class ExtendedInfoTests : EdsTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private const string _FULL_NAME = "persona #1";
  private bool _found_field_1;
  private bool _found_field_2;

  public ExtendedInfoTests ()
    {
      base ("ExtendedInfo");

      this.add_test ("extended info interface", this.test_extended_info);
      this.add_test ("add extended info", this.test_add_extended_info);
    }

  public void test_extended_info ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, Value?> c1 = new Gee.HashMap<string, Value?> ();
      Value? v;

      this.eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string (ExtendedInfoTests._FULL_NAME);
      c1.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string ("value1");
      c1.set ("X-FIELD-1", (owned) v);
      v = Value (typeof (string));
      v.set_string ("value2");
      c1.set ("X-FIELD-2", (owned) v);

      this.eds_backend.add_contact (c1);

      this._found_field_1 = false;
      this._found_field_2 = false;

      this._test_extended_info_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_field_1 == true);
      assert (this._found_field_2 == true);

      this._aggregator = null;
      this._main_loop = null;
    }

  private async void _test_extended_info_async ()
    {
      yield this.eds_backend.commit_contacts_to_addressbook ();

      this._aggregator = IndividualAggregator.dup ();
      this._aggregator.individuals_changed_detailed.connect
          (this._individuals_changed_cb);
      try
        {
          yield this._aggregator.prepare ();
        }
      catch (GLib.Error e)
        {
          GLib.error ("Error when calling prepare: %s", e.message);
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

          if (i.full_name == ExtendedInfoTests._FULL_NAME)
            {
              if (i.get_extended_field ("X-FIELD-1") != null)
                  this._found_field_1 = true;
              if (i.get_extended_field ("X-FIELD-2") != null)
                  this._found_field_2 = true;
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }

      if (this._found_field_1 == true &&
          this._found_field_2 == true)
        {
          this._main_loop.quit ();
        }
    }

  /* Test that adding extended info to an existing contact works, and that the
   * changes are notified as the change_extended_info() call returns. */
  public void test_add_extended_info ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, Value?> c1 = new Gee.HashMap<string, Value?> ();
      Value? v;

      this.eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string (ExtendedInfoTests._FULL_NAME);
      c1.set ("full_name", (owned) v);

      this.eds_backend.add_contact (c1);

      this._test_add_extended_info_async.begin ();
      TestUtils.loop_run_with_timeout (this._main_loop);

      this._aggregator = null;
      this._main_loop = null;
    }

  private async void _test_add_extended_info_async ()
    {
      yield this.eds_backend.commit_contacts_to_addressbook ();

      this._aggregator = IndividualAggregator.dup ();
      this._aggregator.individuals_changed_detailed.connect
          (this._add_individuals_changed_cb);
      try
        {
          yield this._aggregator.prepare ();
        }
      catch (GLib.Error e)
        {
          GLib.error ("Error when calling prepare: %s", e.message);
        }
    }

  private void _add_individuals_changed_cb (
       MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();
      var removed = changes.get_keys ();

      foreach (var i in added)
        {
          assert (i != null);

          if (i.full_name != ExtendedInfoTests._FULL_NAME)
              continue;

          GLib.debug ("Adding an extended field");

          /* Add an extended field and check it’s immediately usable. */
          i.change_extended_field.begin ("X-FOLKS-EXTENDED-INFO",
              new ExtendedFieldDetails ("folks-test", null), (o, r) =>
            {
              try
                {
                  i.change_extended_field.end (r);

                  ExtendedFieldDetails? efd =
                      i.get_extended_field ("X-FOLKS-EXTENDED-INFO");

                  assert (efd != null);
                  assert (efd.value == "folks-test");

                  /* Success. */
                  this._main_loop.quit ();
                }
              catch (GLib.Error e)
                {
                  GLib.error ("Failed to change extended field: %s", e.message);
                }
            });
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

  var tests = new ExtendedInfoTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
