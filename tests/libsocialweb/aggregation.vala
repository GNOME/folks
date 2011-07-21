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

public class AggregationTests : Folks.TestCase
{
  private LibsocialwebTest.Backend _lsw_backend;
  private static const string STORE_FILE_PATH =
      "folks-test-libsocialweb-aggregation-store.ini";
  private static const string KF_RELATIONSHIPS_FILE_PATH =
      "folks-test-libsocialweb-aggregation-relationships.ini";

  public AggregationTests ()
    {
      base ("Aggregation");

      this._lsw_backend = new LibsocialwebTest.Backend ();

      this.add_test ("libsocialweb aggregation", this.test_aggregation_libsocialweb);
    }

  public override void set_up ()
    {
      /* Initialize an empty key file for the relationships*/
      var kf_relationships_path = Path.build_filename (
          Environment.get_tmp_dir (),
          this.KF_RELATIONSHIPS_FILE_PATH, null);
      Environment.set_variable ("FOLKS_BACKEND_KEY_FILE_PATH",
          kf_relationships_path, true);
      string kf_relationships_data = "#\n";
      File kf_relationships_f = File.new_for_path (kf_relationships_path);
      try
        {
          kf_relationships_f.replace_contents (kf_relationships_data,
              kf_relationships_data.length, null, false,
              FileCreateFlags.PRIVATE, null);
        }
      catch (Error e)
        {
          error ("Could not write relationship file '%s': %s",
              kf_relationships_path, e.message);
        }

      /* Use a temporary key file for the BackendStore */
      var kf_path = Path.build_filename (Environment.get_tmp_dir (),
          this.STORE_FILE_PATH, null);

      FileUtils.remove (kf_path);

      GLib.KeyFile kf = new GLib.KeyFile ();
      kf.set_boolean("all-others", "enabled", false);
      kf.set_boolean("libsocialweb", "enabled", true);
      kf.set_boolean("key-file", "enabled", true);

      try
        {
          File backend_f = File.new_for_path (kf_path);
          string data = kf.to_data ();
          backend_f.replace_contents (data,
              data.length, null, false, FileCreateFlags.PRIVATE,
              null);
        }
      catch (Error e)
        {
          error ("Could not write updated backend key file '%s': %s",
              kf_path, e.message);
        }

      Environment.set_variable ("FOLKS_BACKEND_STORE_KEY_FILE_PATH",
          kf_path, true);
    }

  public override void tear_down ()
    {
    }

  public void test_aggregation_libsocialweb ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      this._lsw_backend.ready.connect(() =>
        {
          main_loop.quit ();
        });
      uint timer_id = Timeout.add_seconds (5, () =>
        {
          assert_not_reached ();
        });
      this._lsw_backend.set_up ();
      main_loop.run ();
      Source.remove (timer_id);

      var mysocialnetwork1 = this._lsw_backend.add_service ("mysocialnetwork1");
      var mysocialnetwork2 = this._lsw_backend.add_service ("mysocialnetwork2");

      /* Populate mysocialnetwork1 */
      mysocialnetwork1.OpenViewCalled.connect((query, p, path) =>
        {
          mysocialnetwork1.contact_views[path].StartCalled.connect ( (path) =>
            {
              Idle.add (() =>
                {
                  string text = "([('mysocialnetwork1', 'garg', %x, "
                      + "{'id': ['garg'], 'name': ['Gargantua']})],)";
                  Variant v = new Variant.parsed (text, 1300792578);
                  try
                    {
                      var conn = Bus.get_sync (BusType.SESSION);
                      conn.emit_signal (null, path,
                          "com.meego.libsocialweb.ContactView",
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

      /* Populate mysocialnetwork2 */
      mysocialnetwork2.OpenViewCalled.connect((query, p, path) =>
        {
          mysocialnetwork2.contact_views[path].StartCalled.connect ( (path) =>
            {
              Idle.add (() =>
                {
                  string text = "([('mysocialnetwork2', 'panta', %x, "
                      + "{'id': ['panta'], 'name': ['Pantagruel']})],)";
                  Variant v = new Variant.parsed (text, 1300792579);
                  try
                    {
                      var conn = Bus.get_sync (BusType.SESSION);
                      conn.emit_signal (null, path,
                          "com.meego.libsocialweb.ContactView",
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

      var aggregator = new IndividualAggregator ();
      Individual[] individual_gathered = new Individual[0];
      var handler_id = aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          debug ("initial individuals_changed");
          foreach (Individual i in added)
            individual_gathered += i;
          if (individual_gathered.length >= 2)
            main_loop.quit ();
        });
      aggregator.prepare ();

      timer_id = Timeout.add_seconds (5, () =>
        {
          assert_not_reached ();
        });
      main_loop.run ();
      Source.remove (timer_id);
      aggregator.disconnect (handler_id);

      /* Check the aggregator got the correct data */
      assert (individual_gathered.length == 2);
      assert (
          (((Folks.NameDetails) individual_gathered[0]).nickname == "Gargantua"
           && ((Folks.NameDetails) individual_gathered[1]).nickname == "Pantagruel")
          ||
          (((Folks.NameDetails) individual_gathered[0]).nickname == "Pantagruel"
           && ((Folks.NameDetails) individual_gathered[1]).nickname == "Gargantua"));

      /* Check the result of link_personas */
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          debug ("individuals_changed after link: added:%u removed:%u",
              added.size, removed.size);
          assert (added.size == 1);
          assert (removed.size == 2);

          foreach (var i in added)
            {
              assert (i.personas.size == 3);
              debug ("individuals_changed: 1 individual containing %u personas",
                  i.personas.size);
            }

          main_loop.quit ();
        });

      /* Link personas */
      var personas = new HashSet<Persona> ();

      var personas1 = new GLib.List<unowned Persona> ();
      foreach (var p1 in individual_gathered[0].personas)
        {
          personas.add (p1);
          personas1.append (p1);
        }

      var personas2 = new GLib.List<unowned Persona> ();
      foreach (var p2 in individual_gathered[1].personas)
        {
          personas.add (p2);
          personas2.append (p2);
        }

      assert (personas.size == 2);

      Idle.add (() =>
        {
          aggregator.link_personas (personas);
          return false;
        });

      timer_id = Timeout.add_seconds (5, () =>
        {
          assert_not_reached ();
        });
      main_loop.run ();
      Source.remove (timer_id);

      this._lsw_backend.tear_down ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new AggregationTests ().get_suite ());

  Test.run ();

  return 0;
}