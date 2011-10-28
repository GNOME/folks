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

public class RemovingContactsTests : Folks.TestCase
{
  private EdsTest.Backend _eds_backend;
  private IndividualAggregator _aggregator;
  private GLib.MainLoop _main_loop;
  private bool _removed;
  private bool _added;

  public RemovingContactsTests ()
    {
      base ("IndividualRetrieval");

      this.add_test ("removing contact", this.test_removal);
    }

  public override void set_up ()
    {
      this._eds_backend = new EdsTest.Backend ();
      this._eds_backend.set_up ();

      /* We configure eds as the primary store */
      var config_val = "eds:%s".printf (this._eds_backend.address_book_uid);
      Environment.set_variable ("FOLKS_PRIMARY_STORE", config_val, true);
   }

  public override void tear_down ()
    {
      this._eds_backend.tear_down ();
    }

  void test_removal ()
    {
      Gee.HashMap<string, Value?> c1 = new Gee.HashMap<string, Value?> ();
      this._main_loop = new GLib.MainLoop (null, false);
      Value? v;

      this._added = false;
      this._removed = false;

      this._eds_backend.reset ();

      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      c1.set ("full_name", (owned) v);
      this._eds_backend.add_contact (c1);

      this._test_removal_async ();

      Timeout.add_seconds (5, () => {
            this._main_loop.quit ();
            return false;
          });

      this._main_loop.run ();

      assert (this._added == true);
      assert (this._removed == true);
    }

  private async void _test_removal_async ()
    {
      yield this._eds_backend.commit_contacts_to_addressbook ();

      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = new IndividualAggregator ();
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
          if (i == null)
            {
              continue;
            }

          var name = (Folks.NameDetails) i;
          this._added = true;
          assert (name.full_name == "bernie h. innocenti");
          this._eds_backend.remove_contact (0);
        }

      foreach (Individual i in removed)
        {
          if (i == null)
            {
              continue;
            }

          var name = (Folks.NameDetails) i;
          assert (name.full_name == "bernie h. innocenti");
          this._removed = true;
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new RemovingContactsTests ().get_suite ());

  Test.run ();

  return 0;
}
