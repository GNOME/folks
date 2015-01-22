/*
 * Copyright (C) 2012 Collabora Ltd.
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
 *          Travis Reitter <travis.reitter@collabora.co.uk>
 */

using EdsTest;
using Folks;
using Gee;

public class AntiLinkingTests : EdsTest.TestCase
{
  private IndividualAggregator _aggregator;
  private GLib.MainLoop _main_loop;
  private bool _found_before_update;
  private bool _found_after_update;
  private bool _found_after_final_update;

  /* NOTE: each full name should remain unique */
  private const string _full_name_1 = "bernie h. innocenti";
  private const string _email_1 = "bernie@example.org";
  private const string _full_name_2 = "Clyde McPoyle";

  public AntiLinkingTests ()
    {
      base ("AntiLinking");

      this.add_test ("basic anti-linking", this.test_anti_linking_basic);
      this.add_test ("anti-link removal", this.test_anti_linking_removal);
    }

  public override void set_up ()
    {
      base.set_up ();

      this._found_before_update = false;
      this._found_after_update = false;
      this._found_after_final_update = false;
    }

  public override void tear_down ()
    {
      /* necessary to clean out some stale state */
      this._aggregator = null;

      base.tear_down ();
    }

  /* Confirm that basic anti-linking works for two Personas who have a common
   * linkable property value.
   *
   * FIXME: this test should be moved to tests/folks and rebased upon the Dummy
   * backend once bgo#648811 is fixed.
   */
  void test_anti_linking_basic ()
    {
      Gee.HashMap<string, Value?> c;
      this._main_loop = new GLib.MainLoop (null, false);
      Value? v;

      this._found_before_update = false;
      this._found_after_update = false;

      c = new Gee.HashMap<string, Value?> ();
      v = Value (typeof (string));
      v.set_string (_full_name_1);
      c.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string (_email_1);
      c.set ("email_1", (owned) v);
      this.eds_backend.add_contact (c);

      c = new Gee.HashMap<string, Value?> ();
      v = Value (typeof (string));
      v.set_string (_full_name_2);
      c.set ("full_name", (owned) v);
      v = Value (typeof (string));
      /* Intentionally set the same email address so these will be linked */
      v.set_string (_email_1);
      c.set ("email_1", (owned) v);
      this.eds_backend.add_contact (c);

      this._test_anti_linking_basic_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_before_update);
      assert (this._found_after_update);
    }

  private async void _test_anti_linking_basic_async ()
    {
      yield this.eds_backend.commit_contacts_to_addressbook ();

      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = IndividualAggregator.dup ();
      this._aggregator.individuals_changed_detailed.connect
          (this._individuals_changed_aggregate_after_change_cb);
      try
        {
          yield this._aggregator.prepare ();
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }
    }

  private void _individuals_changed_aggregate_after_change_cb (
       MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();
      var removed = changes.get_values ();

      if (!this._found_before_update)
        {
          assert (changes.size == 1);
          assert (added.size == 1);
          assert (removed.size == 1);

          foreach (Individual i in added)
            {
              assert (i != null);
              assert (i.personas.size == 2);

              this._found_before_update = true;

              var iter = i.personas.iterator ();
              iter.next ();
              var al_1 = iter.get () as AntiLinkable;
              iter.next ();
              var al_2 = iter.get () as AntiLinkable;

              var anti_links = new HashSet<Persona> ();
              anti_links.add (al_2);
              al_1.add_anti_links.begin (anti_links);
            }
        }
      else
        {
          /* the first Individual should have been split in two new ones */
          assert (changes.size == 2);
          assert (added.size == 2);

          var found_1 = false;
          var found_2 = false;

          foreach (var i in added)
            {
              if (i.full_name == _full_name_1)
                {
                  found_1 = true;
                }
              if (i.full_name == _full_name_2)
                {
                  found_2 = true;
                }
            }

          if (found_1 && found_2)
            {
              this._found_after_update = true;
              this._main_loop.quit ();
            }
        }
    }

  /* Confirm that anti-link removal works for two Personas who have a common
   * linkable property value.
   *
   * FIXME: this test should be moved to tests/folks and rebased upon the Dummy
   * backend once bgo#648811 is fixed.
   */
  void test_anti_linking_removal ()
    {
      Gee.HashMap<string, Value?> c;
      this._main_loop = new GLib.MainLoop (null, false);
      Value? v;

      this._found_before_update = false;
      this._found_after_update = false;

      c = new Gee.HashMap<string, Value?> ();
      v = Value (typeof (string));
      v.set_string (_full_name_1);
      c.set ("full_name", (owned) v);
      v = Value (typeof (string));
      v.set_string (_email_1);
      c.set ("email_1", (owned) v);
      this.eds_backend.add_contact (c);

      c = new Gee.HashMap<string, Value?> ();
      v = Value (typeof (string));
      v.set_string (_full_name_2);
      c.set ("full_name", (owned) v);
      v = Value (typeof (string));
      /* Intentionally set the same email address so these will be linked */
      v.set_string (_email_1);
      c.set ("email_1", (owned) v);
      this.eds_backend.add_contact (c);

      this._test_anti_linking_removal_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_before_update);
      assert (this._found_after_update);
      assert (this._found_after_final_update);
    }

  private async void _test_anti_linking_removal_async ()
    {
      yield this.eds_backend.commit_contacts_to_addressbook ();

      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = IndividualAggregator.dup ();
      this._aggregator.individuals_changed_detailed.connect
          (this._individuals_changed_anti_linking_removal_cb);
      try
        {
          yield this._aggregator.prepare ();
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }
    }

  private void _individuals_changed_anti_linking_removal_cb (
       MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();
      var removed = changes.get_values ();

      if (!this._found_before_update)
        {
          assert (changes.size == 1);
          assert (added.size == 1);
          assert (removed.size == 1);

          foreach (Individual i in added)
            {
              assert (i != null);
              assert (i.personas.size == 2);

              this._found_before_update = true;

              var iter = i.personas.iterator ();
              iter.next ();
              var al_1 = iter.get () as AntiLinkable;
              iter.next ();
              var al_2 = iter.get () as AntiLinkable;

              var anti_links = new HashSet<Persona> ();
              anti_links.add (al_2);
              al_1.add_anti_links.begin (anti_links);
            }
        }
      else if (!this._found_after_update)
        {
          /* the first Individual should have been split in two new ones */
          assert (changes.size == 2);
          assert (added.size == 2);

          Individual? ind_1 = null;
          Individual? ind_2 = null;

          foreach (var i in added)
            {
              if (i.full_name == _full_name_1)
                {
                  ind_1 = i;
                }
              if (i.full_name == _full_name_2)
                {
                  ind_2 = i;
                }
            }

          assert (ind_1 != null);
          assert (ind_2 != null);

          this._found_after_update = true;

          Iterator<Persona> iter;
          iter = ind_1.personas.iterator ();
          iter.next ();
          var al_1 = iter.get () as AntiLinkable;

          iter = ind_2.personas.iterator ();
          iter.next ();
          var al_2 = iter.get () as AntiLinkable;

          /* revert anti-links (in both directions) */
          HashSet<Persona> anti_links;
          anti_links = new HashSet<Persona> ();
          anti_links.add (al_2);
          al_1.remove_anti_links.begin (anti_links);

          anti_links = new HashSet<Persona> ();
          anti_links.add (al_1);
          al_2.remove_anti_links.begin (anti_links);
        }
      else
        {
          /* ensure the two Individuals got replaced by a single one */
          assert (removed.size == 2);
          var added_unique = new HashSet<Individual> ();
          added_unique.add_all (added);
          assert (added_unique.size == 1);

          var found_1 = false;
          var found_2 = false;

          /* The Personas should have been re-aggregated here */
          foreach (var i in added)
            {
              foreach (var p in i.personas)
                {
                  if (((NameDetails) p).full_name == _full_name_1)
                    {
                      found_1 = true;
                    }
                  if (((NameDetails) p).full_name == _full_name_2)
                    {
                      found_2 = true;
                    }
                }
            }

          if (found_1 && found_2)
            {
              this._found_after_final_update = true;
              this._main_loop.quit ();
            }
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new AntiLinkingTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
