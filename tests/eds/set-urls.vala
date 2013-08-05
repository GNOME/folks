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

using EdsTest;
using Folks;
using Gee;

public class SetUrlsTests : EdsTest.TestCase
{
  private IndividualAggregator _aggregator;
  private GLib.MainLoop _main_loop;
  private bool _found_before_update;
  private bool _found_url_extra_1;
  private bool _found_url_extra_2;
  private bool _found_url_home;
  private bool _found_url_blog;
  private string _url_extra_1 = "http://example.org";
  private string _url_extra_2 = "http://extra.example.org";
  private string _url_home = "http://home.example.org";
  private string _url_blog = "http://blog.example.org";


  public SetUrlsTests ()
    {
      base ("SetUrls");

      this.add_test ("setting urls on e-d-s persona",
          this.test_set_urls);
    }

  void test_set_urls ()
    {
      Gee.HashMap<string, Value?> c1 = new Gee.HashMap<string, Value?> ();
      this._main_loop = new GLib.MainLoop (null, false);
      Value? v;

      this._found_before_update = false;
      this._found_url_extra_1 = false;
      this._found_url_extra_2 = false;
      this._found_url_home = false;
      this._found_url_blog = false;

      this.eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string ("Albus Percival Wulfric Brian Dumbledore");
      c1.set ("full_name", (owned) v);
      this.eds_backend.add_contact (c1);

      this._test_set_urls_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop, 5);

      assert (this._found_before_update);
      assert (this._found_url_extra_1);
      assert (this._found_url_extra_2);
      assert (this._found_url_home);
      assert (this._found_url_blog);
    }

  private async void _test_set_urls_async ()
    {
      yield this.eds_backend.commit_contacts_to_addressbook ();

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

      foreach (Individual i in added)
        {
          assert (i != null);

          var name = (Folks.NameDetails) i;

          if (name.full_name == "Albus Percival Wulfric Brian Dumbledore")
            {
              i.notify["urls"].connect (this._notify_urls_cb);
              this._found_before_update = true;

              foreach (var p in i.personas)
                {
                  var urls = new HashSet<UrlFieldDetails> ();

                  var p1 = new UrlFieldDetails (this._url_extra_1);
                  urls.add (p1);
                  var p2 = new UrlFieldDetails (this._url_extra_2);
                  urls.add (p2);
                  var p3 = new UrlFieldDetails (this._url_home);
                  p3.set_parameter(AbstractFieldDetails.PARAM_TYPE,
                      UrlFieldDetails.PARAM_TYPE_HOME_PAGE);
                  urls.add (p3);
                  var p4 = new UrlFieldDetails (this._url_blog);
                  p4.set_parameter(AbstractFieldDetails.PARAM_TYPE,
                      UrlFieldDetails.PARAM_TYPE_BLOG);
                  urls.add (p4);

                  ((UrlDetails) p).urls = urls;
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
      foreach (var url in i.urls)
        {
          if (url.value == this._url_extra_1)
            {
              this._found_url_extra_1 = true;
            }
          else if (url.value == this._url_extra_2)
            {
              this._found_url_extra_2 = true;
            }
          else if (url.value == this._url_home)
            {
              this._found_url_home = true;
            }
          else if (url.value == this._url_blog)
            {
              this._found_url_blog = true;
            }
        }

      if (this._found_url_extra_1 &&
          this._found_url_extra_2 &&
          this._found_url_home &&
          this._found_url_blog)
        {
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new SetUrlsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
