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

public class MatchAllTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator = null;
  private string _persona_fullname_1 = "Bernie Innocenti";
  private string _persona_fullname_2 = "Bernardo H. Innocenti";
  private string _persona_fullname_3 = "Travis R.";
  private string _persona_fullname_4 = "Travis Reitter";
  private bool _added_personas = false;
  private string _individual_id_1 = "";
  private string _individual_id_2 = "";
  private string _individual_id_3 = "";
  private string _individual_id_4 = "";
  private Trf.PersonaStore _pstore;
  private GLib.List<int> _matches_all = new GLib.List<int> ();
  private int _matches_1 = 0;

  public MatchAllTests ()
    {
      base ("MatchAllTests");

      this.add_test ("test potential match all ",
          this.test_match_all);
    }

  public void test_match_all ()
    {
      this._main_loop = new GLib.MainLoop (null, false);

     this._test_match_all_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      /* Expected outcome:
       *
       * We call IndividualAggregator.get_potential_matches () for
       * the Individual with name "Bernie Innocenti" with a threshold
       * of MatchResult.MEDIUM so we expect only one match
       * ("Bernardo H. Innocenti").
       *
       * Then we call IndividualAggregator.get_all_potential_matches ()
       * and we expect one match (>= MatchResult.MEDIUM) for each Individual
       * (not counting the user Individual).
       */
      assert (this._matches_1 == 1);
      assert (this._matches_all.length () == 4);
      foreach (var size in this._matches_all)
        {
          assert (size == 1);
        }
   }

  private async void _test_match_all_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();

      if (this._aggregator == null)
        {
          this._aggregator = IndividualAggregator.dup ();
          this._aggregator.individuals_changed_detailed.connect
            (this._individuals_changed_cb);
        }

      try
        {
          yield this._aggregator.prepare ();
          this._pstore = null;
          foreach (var backend in store.enabled_backends.values)
            {
              this._pstore =
                (Trf.PersonaStore) backend.persona_stores.get ("tracker");
              if (this._pstore != null)
                break;
            }
          assert (this._pstore != null);
          this._pstore.notify["is-prepared"].connect (this._notify_pstore_cb);
          this._try_to_add.begin ();
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

          if (i.full_name == this._persona_fullname_1)
            {
              this._individual_id_1 = i.id;
            }
          else if (i.full_name == this._persona_fullname_2)
            {
              this._individual_id_2 = i.id;
            }
          else if (i.full_name == this._persona_fullname_3)
            {
              this._individual_id_3 = i.id;
            }
          else if (i.full_name == this._persona_fullname_4)
            {
              this._individual_id_4 = i.id;
            }
        }

      if (this._individual_id_1 != "" &&
          this._individual_id_2 != "" &&
          this._individual_id_3 != "" &&
          this._individual_id_4 != "")
        {
          this._try_match_all ();
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  private void _try_match_all ()
    {
      var ind1 = this._aggregator.individuals.get (this._individual_id_1);
      var matches_1 = this._aggregator.get_potential_matches (ind1,
          MatchResult.MEDIUM);
      this._matches_1 = matches_1.size;

     var all_matches = this._aggregator.get_all_potential_matches (
          MatchResult.MEDIUM);

      foreach (var i in all_matches.keys)
        {
          if (i.is_user)
            continue;
          var matches = all_matches.get (i);
          this._matches_all.prepend (matches.size);
        }

      this._main_loop.quit ();
    }

  private void _notify_pstore_cb (Object _pstore, ParamSpec ps)
    {
      this._try_to_add.begin ();
    }

  private async void _try_to_add ()
    {
      if (this._pstore.is_prepared && this._added_personas == false)
        {
          this._added_personas = true;
          yield this._add_personas ();
        }
    }

  private async void _add_personas ()
    {
      yield this._do_add_persona (this._persona_fullname_1);
      yield this._do_add_persona (this._persona_fullname_2);
      yield this._do_add_persona (this._persona_fullname_3);
      yield this._do_add_persona (this._persona_fullname_4);
    }

  private async void _do_add_persona (string fn)
    {
      HashTable<string, Value?> details = new HashTable<string, Value?>
          (str_hash, str_equal);
      Value? val;

      val = Value (typeof (string));
      val.set_string (fn);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.FULL_NAME),
          (owned) val);

     try
        {
          yield this._aggregator.add_persona_from_details (null,
              this._pstore, details);
        }
      catch (Folks.IndividualAggregatorError e)
        {
          GLib.warning ("[AddPersonaError] add_persona_from_details: %s\n",
              e.message);
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new MatchAllTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
