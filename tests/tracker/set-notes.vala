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

public class SetNotesTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private bool _note_found;
  private NoteFieldDetails _note;

  public SetNotesTests ()
    {
      base ("SetNotesTests");

      this.add_test ("test setting notes ",
          this.test_set_notes);
    }

  public void test_set_notes ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._persona_fullname = "persona #1";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      ((!) this.tracker_backend).add_contact (c1);

      this._note = new NoteFieldDetails ("some note");

      ((!) this.tracker_backend).set_up ();

      this._note_found = false;

      this._test_set_notes_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._note_found);
    }

  private async void _test_set_notes_async ()
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
              i.notify["notes"].connect (this._notify_notes_cb);

              Gee.HashSet<NoteFieldDetails> notes =
                  new HashSet<NoteFieldDetails> (
                      AbstractFieldDetails<string>.hash_static,
                      AbstractFieldDetails<string>.equal_static);
              var n = new NoteFieldDetails ("some note");
              notes.add ((owned) n);

              foreach (var p in i.personas)
                {
                  ((NoteDetails) p).notes = notes;
                }
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  private void _notify_notes_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      if (i.full_name == this._persona_fullname)
        {
          foreach (var n in i.notes)
            {
              if (n.equal (this._note))
                {
                  this._note_found = true;
                  this._main_loop.quit ();
                }
            }
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new SetNotesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
