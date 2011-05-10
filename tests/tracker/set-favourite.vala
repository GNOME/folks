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

public class SetFavouriteTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private string _initial_fullname_1 = "persona #1";
  private string _initial_fullname_2 = "persona #2";
  private bool _c1_initially_not_favourite;
  private bool _c1_finally_favourite;
  private bool _c2_initially_favourite;
  private bool _c2_finally_not_favourite;

  public SetFavouriteTests ()
    {
      base ("SetFavouriteTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test setting favourite ", this.test_set_alias);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_set_alias ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      Gee.HashMap<string, string> c2 = new Gee.HashMap<string, string> ();
      this._initial_fullname_1 = "persona #1";
      this._initial_fullname_2 = "persona #2";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._initial_fullname_1);
      this._tracker_backend.add_contact (c1);

      c2.set (Trf.OntologyDefs.NCO_FULLNAME, this._initial_fullname_2);
      c2.set (Trf.OntologyDefs.NAO_TAG, "");
      this._tracker_backend.add_contact (c2);

      this._tracker_backend.set_up ();

      this._c1_initially_not_favourite = false;
      this._c1_finally_favourite = false;
      this._c2_initially_favourite = false;
      this._c2_finally_not_favourite = false;

      this._test_set_alias_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      /* Note:
       *  the is-favourite property is notified as a
       *  consequence of a value changed event fired by
       *  Tracker
       */
      assert (this._c1_initially_not_favourite);
      assert (this._c1_finally_favourite);
      assert (this._c2_initially_favourite);
      assert (this._c2_finally_not_favourite);

      this._tracker_backend.tear_down ();
    }

  private async void _test_set_alias_async ()
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
          i.notify["is-favourite"].connect (this._notify_favourite_cb);
          if (i.full_name == this._initial_fullname_1)
            {
              if (i.is_favourite == false)
                {
                  this._c1_initially_not_favourite = true;

                  foreach (var p in i.personas)
                    {
                      ((FavouriteDetails) p).is_favourite = true;
                    }
                }
            }
          else if (i.full_name == this._initial_fullname_2)
            {
              if (i.is_favourite == true)
                {
                  this._c2_initially_favourite = true;

                  foreach (var p in i.personas)
                    {
                      ((FavouriteDetails) p).is_favourite = false;
                    }
                }
            }
        }

      assert (removed.size == 0);
    }

  private void _notify_favourite_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      if (i.full_name == this._initial_fullname_1)
        {
          if (i.is_favourite == true)
            this._c1_finally_favourite = true;
        }
      else if (i.full_name == this._initial_fullname_2)
        {
          if (i.is_favourite == false)
            this._c2_finally_not_favourite = true;
        }

      if (this._c1_finally_favourite &&
          this._c2_finally_not_favourite)
        this._main_loop.quit ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new SetFavouriteTests ().get_suite ());

  Test.run ();

  return 0;
}