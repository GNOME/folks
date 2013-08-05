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
 * Authors: Alban Crequy <alban.crequy@collabora.co.uk>
 *
 */

using LibsocialwebTest;
using Folks;
using Gee;
using GLib;
using SocialWebClient;

public class DummyLswTests : LibsocialwebTest.TestCase
{
  public DummyLswTests ()
    {
      base ("DummyLsw");

      this.add_test ("dummy libsocialweb", this.test_dummy_libsocialweb);
    }

  public void test_dummy_libsocialweb ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      var lsw_backend = (!) this.lsw_backend;
      var mysocialnetwork = lsw_backend.add_service ("mysocialnetwork");
      var p = new GLib.HashTable<string,string> (null, null);

      try
        {
          var view_path = mysocialnetwork.OpenView("feed", p);
          var conn = Bus.get_sync (BusType.SESSION);
          conn.get_proxy<LibsocialwebTest.ContactView>
              .begin<LibsocialwebTest.ContactView> (
              "org.gnome.libsocialweb", view_path, 0, null, (v) =>
            {
              LibsocialwebTest.ContactView view
                  = (LibsocialwebTest.ContactView)v;
              view.Start.begin ();
              mysocialnetwork.contact_views[view_path].ContactsAdded
                  (new LibsocialwebTest.LibsocialwebContactViewTest
                      .ContactsAddedElement[0]);
              mysocialnetwork.contact_views[view_path].ContactsAdded
                  (new LibsocialwebTest.LibsocialwebContactViewTest
                      .ContactsAddedElement[0]);
              main_loop.quit ();
            });
        }
      catch (GLib.IOError e)
        {
          assert_not_reached ();
        }

      TestUtils.loop_run_with_timeout (main_loop, 5);

      /* Test adding two contacts */

      string view_path = "";
      mysocialnetwork.OpenViewCalled.connect((query, p, path) =>
        {
          debug ("mysocialnetwork.OpenViewCalled.connect");
          view_path = path;
          mysocialnetwork.contact_views[path].StartCalled.connect ( (path) =>
            {
              debug ("OpenViewCalled.connect");
              Idle.add (() =>
                {
                  string text = "([('mysocialnetwork', 'id01', %x, "
                      + "{'id': ['id01'], 'name': ['Gargantua'], "
                       + "'X-foo': ['secret']}), "
                     + "('mysocialnetwork', 'id02', %x, "
                      + "{'id': ['id02'], 'name': ['Pantagruel']})],)";
                  Variant v = new Variant.parsed (text, 1300792578, 1300792579);
                  try
                    {
                      var conn = Bus.get_sync (BusType.SESSION);
                      conn.emit_signal (null, path,
                          "org.gnome.libsocialweb.ContactView",
                          "ContactsAdded", v);
                    }
                  catch (GLib.IOError e)
                    {
                      assert_not_reached ();
                    }
                  catch (GLib.Error e)
                    {
                      assert_not_reached ();
                    }
                  return false;
                });
            });
        });

      var aggregator = IndividualAggregator.dup ();
      Individual? i1 = null;
      Individual? i2 = null;
      var handler_id =
          aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          debug ("Aggregator got some data!");
          assert (added.size == 2);
          assert (removed.size == 1);
          foreach (var i in added)
            {
              string nickname = ((Folks.NameDetails) i).nickname;
              if (nickname == "Gargantua")
                i1 = i;
              if (nickname == "Pantagruel")
                i2 = i;
            }

          foreach (var i in removed)
            {
              assert (i == null);
            }

          main_loop.quit ();
        });
      aggregator.prepare.begin ();

      TestUtils.loop_run_with_timeout (main_loop, 5);
      aggregator.disconnect (handler_id);
      assert (i1 != null);
      assert (i2 != null);
      Folks.Persona persona1 = null;
      Folks.Persona persona2 = null;
      foreach (var p1 in i1.personas)
        {
          persona1 = p1;
          break;
        }
      foreach (var p2 in i2.personas)
        {
          persona2 = p2;
          break;
        }
      assert (persona1 is Swf.Persona);
      assert (persona2 is Swf.Persona);
      Contact contact1 = ((Swf.Persona) persona1).lsw_contact;
      Contact contact2 = ((Swf.Persona) persona2).lsw_contact;
      assert (contact1 != null);
      assert (contact2 != null);
      assert (contact1.get_value ("id") == "id01");
      assert (contact1.get_value ("X-foo") == "secret");
      assert (contact1.get_value ("X-bar") == null);
      assert (contact2.get_value ("id") == "id02");
      assert (contact2.get_value ("X-foo") == null);


      /* Test changing a contact */
      Idle.add (() =>
        {
          string text = "([('mysocialnetwork', 'id01', %x, "
              + "{'id': ['id01'], 'name': ['Rabelais'], "
               + "'X-foo': ['secret'], 'X-bar': ['bar']})],)";
          Variant v = new Variant.parsed (text, 1300792581);
          try
            {
              var conn = Bus.get_sync (BusType.SESSION);
              conn.emit_signal (null, view_path,
                  "org.gnome.libsocialweb.ContactView",
                  "ContactsChanged", v);
            }
          catch (GLib.IOError e)
            {
              assert_not_reached ();
            }
          catch (GLib.Error e)
            {
              assert_not_reached ();
            }
          return false;
        });
      handler_id = i1.notify["nickname"].connect (
          () =>
        {
          debug ("Aggregator changed some data!");
	  string nickname = ((Folks.NameDetails) i1).nickname;
          assert (nickname == "Rabelais");
	  assert (contact1.get_value ("id") == "id01");
	  assert (contact1.get_value ("X-foo") == "secret");
	  assert (contact1.get_value ("X-bar") == "bar");
          main_loop.quit ();
        });

      TestUtils.loop_run_with_timeout (main_loop, 5);
      i1.disconnect (handler_id);

      /* Test deleting two contacts */
      Idle.add (() =>
        {
          string text = "([('mysocialnetwork', 'id01'), "
             + "('mysocialnetwork', 'id02')],)";
          Variant v = new Variant.parsed (text);
          try
            {
              var conn = Bus.get_sync (BusType.SESSION);
              conn.emit_signal (null, view_path,
                  "org.gnome.libsocialweb.ContactView",
                  "ContactsRemoved", v);
            }
          catch (GLib.IOError e)
            {
              assert_not_reached ();
            }
          catch (GLib.Error e)
            {
              assert_not_reached ();
            }
          return false;
        });

      handler_id = aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var added = changes.get_values ();
          var removed = changes.get_keys ();

          debug ("Aggregator deleted some data!");
          assert (added.size == 2);
          assert (removed.size == 2);

          foreach (var i in removed)
            {
              assert (i != null);

              string nickname = ((Folks.NameDetails) i).nickname;
              debug ("deleted nickname: %s", nickname);
            }

          foreach (var i in added)
            {
              assert (i == null);
            }

          main_loop.quit ();
        });

      TestUtils.loop_run_with_timeout (main_loop, 5);
      aggregator.disconnect (handler_id);
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new DummyLswTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
