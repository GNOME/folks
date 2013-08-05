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

public class UrlDetailsInterfaceTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _blog_url;
  private string _website_url;
  private string _urls;
  private bool _found_blog;
  private bool _found_website;

  public UrlDetailsInterfaceTests ()
    {
      base ("UrlDetailsInterfaceTests");

      ((!) this.tracker_backend).debug = false;

      this.add_test ("test url details interface",
          this.test_url_details_interface);
    }

  public void test_url_details_interface ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._blog_url = "http://blog.example.org";
      this._website_url = "http://www.example.org";
      this._urls = "%s,%s".printf (this._blog_url, this._website_url);

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, "persona #1");
      c1.set (TrackerTest.Backend.URLS, this._urls);
      ((!) this.tracker_backend).add_contact (c1);

      ((!) this.tracker_backend).set_up ();

      this._found_blog = false;
      this._found_website = false;

      this._test_url_details_interface_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._found_blog == true);
      assert (this._found_website == true);
    }

  private async void _test_url_details_interface_async ()
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

          string full_name = i.full_name;
          if (full_name != null)
            {
              foreach (var url in i.urls)
                {
                  if (url.value == this._blog_url)
                    {
                      this._found_blog = true;
                    }
                  else if (url.value == this._website_url)
                    {
                      this._found_website = true;
                    }
                }
            }
        }

      if (this._found_blog &&
          this._found_website)
        this._main_loop.quit ();

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new UrlDetailsInterfaceTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
