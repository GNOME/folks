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

public class SetStructuredNameTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private bool _sname_found;
  private StructuredName _sname;
  private string _family_name;
  private string _given_name;
  private string _additional_names;
  private string _prefixes;
  private string _suffixes;

  public SetStructuredNameTests ()
    {
      base ("SetStructuredNameTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test setting structured name ",
          this.test_set_structured_name);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_set_structured_name ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._persona_fullname = "persona #1";
      this._family_name = "family name";
      this._given_name = "given name";
      this._additional_names = "additional name";
      this._prefixes = "prefixes";
      this._suffixes = "suffixes";

      this._sname = new StructuredName (this._family_name, this._given_name,
          this._additional_names, this._prefixes, this._suffixes);

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      this._tracker_backend.add_contact (c1);

      this._tracker_backend.set_up ();

      this._sname_found = false;

      this._test_set_structured_name_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._sname_found);

      this._tracker_backend.tear_down ();
    }

  private async void _test_set_structured_name_async ()
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
              foreach (var p in i.personas)
                {
                  p.notify["structured-name"].connect (this._notify_sname_cb);
                  ((NameDetails) p).structured_name = this._sname;
                }
            }
        }

      assert (removed == null);
    }

  private void _notify_sname_cb (Object persona, ParamSpec ps)
    {
      Trf.Persona p = (Trf.Persona) persona;
      if (p.full_name == this._persona_fullname)
        {
          if (p.structured_name.is_empty () == false &&
              p.structured_name.equal (this._sname) == true)
            {
              this._sname_found = true;
              this._main_loop.quit ();
            }
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new SetStructuredNameTests ().get_suite ());

  Test.run ();

  return 0;
}
