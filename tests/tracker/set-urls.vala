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

public class SetURLsTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  Gee.HashMap<string, string> _urls;

  public SetURLsTests ()
    {
      base ("SetURLsTests");

      this.add_test ("test setting urls ", this.test_set_urls);
    }

  public void test_set_urls ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._persona_fullname = "persona #1";
      this._urls = new Gee.HashMap<string, string> ();
      this._urls.set (UrlFieldDetails.PARAM_TYPE_BLOG,
          "http://one.example.org");
      this._urls.set (UrlFieldDetails.PARAM_TYPE_HOME_PAGE,
          "http://two.example.org");
      this._urls.set (AbstractFieldDetails.PARAM_TYPE_OTHER,
          "http://three.example.org");

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      ((!) this.tracker_backend).add_contact (c1);

      ((!) this.tracker_backend).set_up ();

      this._test_set_urls_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._urls.size == 0);
    }

  private async void _test_set_urls_async ()
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
              i.notify["urls"].connect (this._notify_urls_cb);

              var url_fds = new HashSet<UrlFieldDetails> (
                  AbstractFieldDetails<string>.hash_static,
                  AbstractFieldDetails<string>.equal_static);
              var p1 = new UrlFieldDetails (
                  this._urls.get (UrlFieldDetails.PARAM_TYPE_BLOG));
              p1.set_parameter (AbstractFieldDetails.PARAM_TYPE, UrlFieldDetails.PARAM_TYPE_BLOG);
              url_fds.add (p1);
              var p2 = new UrlFieldDetails (
                  this._urls.get (UrlFieldDetails.PARAM_TYPE_HOME_PAGE));
              p2.set_parameter (AbstractFieldDetails.PARAM_TYPE, UrlFieldDetails.PARAM_TYPE_HOME_PAGE);
              url_fds.add (p2);
              var p3 = new UrlFieldDetails (
                  this._urls.get (AbstractFieldDetails.PARAM_TYPE_OTHER));
              url_fds.add (p3);

              foreach (var p in i.personas)
                {
                  ((UrlDetails) p).urls = url_fds;
                }
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  private void _notify_urls_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      if (i.full_name == this._persona_fullname)
        {
          foreach (var p in i.urls)
            {
              var type_p = p.get_parameter_values (AbstractFieldDetails.PARAM_TYPE);

              if (type_p != null &&
                  type_p.contains (UrlFieldDetails.PARAM_TYPE_BLOG) &&
                  p.value == this._urls.get (UrlFieldDetails.PARAM_TYPE_BLOG))
                {
                  this._urls.unset (UrlFieldDetails.PARAM_TYPE_BLOG);
                }
              else if (type_p != null &&
                  type_p.contains (UrlFieldDetails.PARAM_TYPE_HOME_PAGE) &&
                  p.value == this._urls.get (UrlFieldDetails.PARAM_TYPE_HOME_PAGE))
                {
                  this._urls.unset (UrlFieldDetails.PARAM_TYPE_HOME_PAGE);
                }
              else if (type_p == null &&
                  p.value == this._urls.get (AbstractFieldDetails.PARAM_TYPE_OTHER))
                {
                  this._urls.unset (AbstractFieldDetails.PARAM_TYPE_OTHER);
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

  var tests = new SetURLsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
