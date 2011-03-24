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

public class SetURLsTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  Gee.HashMap<string, string> _urls;

  public SetURLsTests ()
    {
      base ("SetURLsTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test setting urls ", this.test_set_urls);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_set_urls ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._persona_fullname = "persona #1";
      this._urls = new Gee.HashMap<string, string> ();
      this._urls.set ("blog", "http://one.example.org");
      this._urls.set ("website", "http://two.example.org");
      this._urls.set ("url", "http://three.example.org");

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      this._tracker_backend.add_contact (c1);

      this._tracker_backend.set_up ();

      this._test_set_urls_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._urls.size == 0);

     this._tracker_backend.tear_down ();
    }

  private async void _test_set_urls_async ()
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
          if (i.full_name == this._persona_fullname)
            {
              i.notify["urls"].connect (this._notify_urls_cb);

              var urls = new HashSet<FieldDetails> ();
              var p1 = new FieldDetails (this._urls.get ("blog"));
              p1.set_parameter ("type", "blog");
              urls.add (p1);
              var p2 = new FieldDetails (this._urls.get ("website"));
              p2.set_parameter ("type", "website");
              urls.add (p2);
              var p3 = new FieldDetails (this._urls.get ("url"));
              p3.set_parameter ("type", "url");
              urls.add (p3);

              foreach (var p in i.personas)
                {
                  ((UrlDetails) p).urls = urls;
                }
            }
        }

      assert (removed.size == 0);
    }

  private void _notify_urls_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      if (i.full_name == this._persona_fullname)
        {
          foreach (var p in i.urls)
            {
              var type_p = p.get_parameter_values ("type");

              if (type_p.contains ("blog") &&
                  p.value == this._urls.get ("blog"))
                {
                  this._urls.unset ("blog");
                }
              else if (type_p.contains ("website") &&
                  p.value == this._urls.get ("website"))
                {
                  this._urls.unset ("website");
                }
              else if (type_p.contains ("url") &&
                  p.value == this._urls.get ("url"))
                {
                  this._urls.unset ("url");
                }
            }
        }

      if (this._urls.size == 0)
        this._main_loop.quit ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new SetURLsTests ().get_suite ());

  Test.run ();

  return 0;
}
