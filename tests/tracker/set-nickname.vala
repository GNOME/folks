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

public class SetNicknameTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private string _initial_nickname;
  private string _modified_nickname;
  private bool _initial_nickname_found;
  private bool _modified_nickname_found;

  public SetNicknameTests ()
    {
      base ("SetNicknameTests");

      this.add_test ("test setting nickname ", this.test_set_nickname);
    }

  public void test_set_nickname ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._persona_fullname = "persona #1";
      this._initial_nickname = "initial nickname";
      this._modified_nickname = "modified nickname";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      c1.set (Trf.OntologyDefs.NCO_NICKNAME, this._initial_nickname);
      ((!) this.tracker_backend).add_contact (c1);

      ((!) this.tracker_backend).set_up ();

      this._initial_nickname_found = false;
      this._modified_nickname_found = false;

      this._test_set_nickname_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._initial_nickname_found == true);
      assert (this._modified_nickname_found == true);
    }

  private async void _test_set_nickname_async ()
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
              if (i.nickname == this._initial_nickname)
                {
                  this._initial_nickname_found = true;

                  foreach (var p in i.personas)
                    {

                      /*
                       * We connect to the Persona's handler because
                       * Individual won't forward the notification to us
                       * unless it comes from a writeable store.
                       */
                      p.notify["nickname"].connect (this._notify_nickname_cb);

                      /* FIXME:
                       * it would be nice if we could just do:
                       *    i.nickname = "foobar"
                       * but we depend on:
                       * https://bugzilla.gnome.org/show_bug.cgi?id=645441 */
                      if (p is NameDetails)
                        {
                          ((NameDetails) p).nickname = this._modified_nickname;
                        }
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

  private void _notify_nickname_cb (Object persona, ParamSpec ps)
    {
      Trf.Persona p = (Trf.Persona) persona;
      if (p.nickname == this._modified_nickname)
        {
          this._modified_nickname_found = true;
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new SetNicknameTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
