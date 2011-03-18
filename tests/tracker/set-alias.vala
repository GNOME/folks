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

public class SetAliasTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private string _initial_alias;
  private string _modified_alias;
  private bool _initial_alias_found;
  private bool _modified_alias_found;

  public SetAliasTests ()
    {
      base ("SetAliasTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test setting alias ", this.test_set_alias);
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
      this._persona_fullname = "persona #1";
      this._initial_alias = "initial alias";
      this._modified_alias = "modified alias";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);

      /* Note:
       *
       * we treat the nco:nickname associated to an nco:PersonContact
       * as the alias, and the nco:nickname(s) associated to IM accounts
       * as possible nicknames. */
      c1.set (Trf.OntologyDefs.NCO_NICKNAME, this._initial_alias);
      this._tracker_backend.add_contact (c1);

      this._tracker_backend.set_up ();

      this._initial_alias_found = false;
      this._modified_alias_found = false;

      this._test_set_alias_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._initial_alias_found == true);
      assert (this._modified_alias_found == true);

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
      (GLib.List<Individual>? added,
       GLib.List<Individual>? removed,
       string? message,
       Persona? actor,
       GroupDetails.ChangeReason reason)
    {
      foreach (unowned Individual i in added)
        {
          if (i.full_name == this._persona_fullname)
            {
              if (i.alias == this._initial_alias)
                {
                  this._initial_alias_found = true;

                  Trf.Persona p = (Trf.Persona)i.personas.nth_data (0);

                  /*
                   * We connect to the Persona's handler because
                   * Individual won't forward the notification to us
                   * unless it comes from a writeable store.
                   */
                  p.notify["alias"].connect (this._notify_alias_cb);

                  /* FIXME:
                   * it would be nice if we could just do:
                   *    i.alias = "foobar"
                   * but we depend on:
                   * https://bugzilla.gnome.org/show_bug.cgi?id=645441 */
                  p.alias = this._modified_alias;
                }
            }
        }

      assert (removed == null);
    }

  private void _notify_alias_cb (Object persona, ParamSpec ps)
    {
      Trf.Persona p = (Trf.Persona) persona;
      if (p.alias == this._modified_alias)
        {
          this._modified_alias_found = true;
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new SetAliasTests ().get_suite ());

  Test.run ();

  return 0;
}
