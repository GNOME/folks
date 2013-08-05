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

public class RemovePersonaTests : EdsTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private bool _persona_removed;
  private bool _individual_removed;
  private string _individual_id;
  private PersonaStore _pstore;
  private string _persona_id;
  private Individual _individual;
  private bool _added_persona = false;

  public RemovePersonaTests ()
    {
      base ("RemovePersonaTests");

      this.add_test ("test removing personas from e-d-s ",
          this.test_remove_persona);
    }

  public void test_remove_persona ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._persona_fullname = "persona #1";

      this._persona_removed = false;
      this._individual_removed = false;

      this._test_remove_persona_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._persona_removed == true);
      assert (this._individual_removed == true);
    }

  private async void _test_remove_persona_async ()
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

  private void _notify_pstore_cb (Object _pstore, ParamSpec ps)
    {
      this._try_to_add ();
    }

  private void _try_to_add ()
    {
      if (this._pstore.is_prepared &&
          this._added_persona == false)
        {
          this._added_persona = true;
          this._add_persona.begin ();
        }
    }

  private async void _add_persona ()
    {
      HashTable<string, Value?> details = new HashTable<string, Value?>
          (str_hash, str_equal);
      Value? v1 = Value (typeof (string));
      v1.set_string (this._persona_fullname);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.FULL_NAME),
          (owned) v1);

      try
        {
          yield this._aggregator.add_persona_from_details
              (null, this._pstore, details);
        }
      catch (Folks.IndividualAggregatorError e)
        {
          GLib.warning ("[RemovePersonaError] add_persona_from_details: %s\n",
              e.message);
        }
    }

  private void _individuals_changed_cb (
       MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();
      var removed = changes.get_keys ();

      foreach (var i in added)
        {
          if (i == null)
            {
              continue;
            }

          if (i.full_name == this._persona_fullname)
            {
              this._individual_id = i.id;

              /* Only examine the first persona */
              foreach (var p in i.personas)
                {
                  this._persona_id = p.iid;
                  break;
                }

              this._individual = i;
              if (this._pstore.personas.has_key (this._persona_id) == true)
                {
                  this._pstore.personas_changed.connect (this._personas_cb);
                  this._aggregator.remove_individual.begin (this._individual);
                }
            }
        }

      foreach (var i in removed)
        {
          if (i == null)
            {
              continue;
            }

          if (i.id == this._individual_id)
            {
              this._individual_removed = true;
            }
        }
    }

  private void _personas_cb ()
    {
      if (this._pstore.personas.has_key (this._persona_id) == false)
        {
          this._persona_removed = true;
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new RemovePersonaTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
