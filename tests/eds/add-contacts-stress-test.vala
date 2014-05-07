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

using Folks;
using Gee;

public class AddContactsStressTestTests : EdsTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private Edsf.PersonaStore _pstore;
  private bool _added_contacts = false;
  private HashTable<string, bool> _contacts_found;
  private int _contacts_cnt = 1000;
  private DateTime _start_time;

  public AddContactsStressTestTests ()
    {
      base ("AddContactsStressTestTests");

      var test_desc = "stress testing adding (%d) contacts to e-d-s ".printf (
          this._contacts_cnt);
      this.add_test (test_desc, this.test_add_contacts);
    }

  public void test_add_contacts ()
    {
      this._main_loop = new GLib.MainLoop (null, false);

      this._contacts_found = new HashTable<string, bool> (str_hash, str_equal);
      for (var i = 0; i < this._contacts_cnt; i++)
        {
          var persona_name = "full_name -%d".printf (i);
          this._contacts_found.insert (persona_name, false);
        }

      this._start_time = new DateTime.now_utc ();
      assert (this._start_time != null);

      this._test_add_persona_async.begin ();

      this._main_loop.run ();

      var now = new DateTime.now_utc ();
      assert (now != null);
      var difference = now.difference (this._start_time);

      var diff = difference / TimeSpan.SECOND;
      GLib.stdout.printf ("(Elapsed time: %" + int64.FORMAT + " secs) ", diff);

      int found = 0;
      foreach (var k in this._contacts_found.get_values ())
        {
          if (k)
            found++;
        }

      assert (found == this._contacts_cnt);
    }

  private async void _test_add_persona_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = IndividualAggregator.dup ();
      this._aggregator.individuals_changed_detailed.connect
          (this._individuals_changed_cb);
      try
        {
          yield this._aggregator.prepare ();

          this._pstore = null;
          foreach (var backend in store.enabled_backends.values)
            {
              this._pstore =
                (Edsf.PersonaStore) backend.persona_stores.get (
                    this.eds_backend.address_book_uid);
              if (this._pstore != null)
                break;
            }
          assert (this._pstore != null);
          this._pstore.notify["is-prepared"].connect (this._notify_pstore_cb);
          this._try_to_add ();
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }
    }

  private async void _add_contacts ()
    {
     for (var i=0; i<this._contacts_cnt; i++)
       {
         var persona_name = "full_name -%d".printf (i);
         HashTable<string, Value?> details = new HashTable<string, Value?>
           (str_hash, str_equal);

         Value? v1 = Value (typeof (string));
         v1.set_string (persona_name);
         details.insert (Folks.PersonaStore.detail_key (
                 PersonaDetail.FULL_NAME),
             (owned) v1);

         try
           {
             yield this._aggregator.add_persona_from_details (null,
                 this._pstore, details);
           }
         catch (Folks.IndividualAggregatorError e)
           {
             GLib.warning ("[AddContactsStressTest]: %d: %s\n", i,
                 e.message);
           }
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

          assert (this._contacts_found.lookup (i.full_name) == false);
          this._contacts_found.replace (i.full_name, true);
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }

      this._exit_if_all_contacts_found ();
    }

  private void _notify_pstore_cb (Object _pstore, ParamSpec ps)
    {
      this._try_to_add ();
    }

  private void _try_to_add ()
    {
      lock (this._added_contacts)
        {
          if (this._pstore.is_prepared &&
              this._added_contacts == false)
            {
              this._added_contacts = true;
              this._add_contacts.begin ();
            }
        }
    }

  private void _exit_if_all_contacts_found ()
    {
      foreach (var k in this._contacts_found.get_keys ())
        {
          var v = this._contacts_found.lookup (k);
          if (v == false)
            return;
        }
      this._main_loop.quit ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new AddContactsStressTestTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
