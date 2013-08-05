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

public class NoteDetailsInterfaceTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private bool _found_note;
  private string _note;
  private string _fullname = "persona #1";

  public NoteDetailsInterfaceTests ()
    {
      base ("NoteDetailsInterfaceTests");

      ((!) this.tracker_backend).debug = false;

      this.add_test ("test note details interface",
          this.test_note_details_interface);
    }

  public void test_note_details_interface ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._fullname = "persona #1";
      this._note = "this is a note";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._fullname);
      c1.set (Trf.OntologyDefs.NCO_NOTE, this._note);
      ((!) this.tracker_backend).add_contact (c1);

      ((!) this.tracker_backend).set_up ();

      this._found_note = false;

      this._test_note_details_interface_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_note == true);
    }

  private async void _test_note_details_interface_async ()
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

          if (i.full_name == this._fullname)
            {
              i.notify["notes"].connect (this._notify_note_cb);
              foreach (var note_fd in i.notes)
                {
                  var note_fd_expected = new NoteFieldDetails (this._note, null,
                      null);

                  /* We copy the tracker_id - we don't know it.
                   * We could get it from the 1st personas iid but there is no
                   * real need. */
                  note_fd_expected.id = note_fd.id;

                  if (note_fd.equal (note_fd_expected))
                    {
                      /* Ensure that setting the Note uid directly (which is
                       * deprecated) is equivalent to setting the id on a
                       * NoteFieldDetails directly */
                      var note_fd_2 = new NoteFieldDetails (
                          note_fd_expected.value, null, note_fd.id);
                      assert (note_fd.equal (note_fd_2));
                      assert (note_fd.id == note_fd_2.id);

                      this._found_note = true;
                      this._main_loop.quit ();
                    }
                }
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  void _notify_note_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual individual = (Folks.Individual) individual_obj;
      foreach (var n in individual.notes)
        {
          if (n.equal (new NoteFieldDetails (this._note)))
            {
              this._found_note = true;
              this._main_loop.quit ();
            }
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new NoteDetailsInterfaceTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
