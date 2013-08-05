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

public class SetDuplicateEmailTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _persona_fullname_1 = "persona #1";
  private string _email_1 = "some-address@example.org";
  private bool _added_personas = false;
  private Trf.PersonaStore _pstore;
  private bool _email_found;

  public SetDuplicateEmailTests ()
    {
      base ("SetDuplicateEmailTests");

      this.add_test ("test re-setting an existing e-mail address",
          this.test_set_duplicate_email);
    }

  public void test_set_duplicate_email ()
    {
      this._main_loop = new GLib.MainLoop (null, false);

      this._email_found = false;
      this._test_set_duplicate_email_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);
      /* we should see the e-mail address twice:
       * 1) when we create the Persona
       * 2) when we re-set the address */
      assert (this._email_found == true);
    }

  private async void _test_set_duplicate_email_async ()
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
                (Trf.PersonaStore) backend.persona_stores.get ("tracker");
              if (this._pstore != null)
                break;
            }
          assert (this._pstore != null);
          this._pstore.notify["is-prepared"].connect (this._notify_pstore_cb);
          this._try_to_add.begin ();
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

          if (i.full_name == this._persona_fullname_1)
            {
              this._reset_email_address (i);
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  private void _reset_email_address (Individual i)
    {
      foreach (var p in i.personas)
        {
          if (this._has_email ((Trf.Persona) p, this._email_1))
            {
              var emails1 = new HashSet<EmailFieldDetails> (
                  AbstractFieldDetails<string>.hash_static,
                  AbstractFieldDetails<string>.equal_static);
              var email_1 = new EmailFieldDetails (this._email_1);
              emails1.add (email_1);
              ((EmailDetails) p).email_addresses = emails1;
              p.notify["email-addresses"].connect (this._email_addresses_cb);
            }
        }
    }

  private void _email_addresses_cb (Object p, ParamSpec ps)
    {
      var persona = (Trf.Persona) p;
      if (this._has_email (persona, this._email_1))
        {
          this._email_found = true;
          this._main_loop.quit ();
        }
    }

  private bool _has_email (Trf.Persona persona, string email)
    {
      if (persona.email_addresses != null)
        {
          foreach (var fd in persona.email_addresses)
            {
              if (fd.value == email)
                {
                  return true;
                }
            }
        }

      return false;
    }

  private void _notify_pstore_cb (Object _pstore, ParamSpec ps)
    {
      this._try_to_add.begin ();
    }

  private async void _try_to_add ()
    {
      if (this._pstore.is_prepared && this._added_personas == false)
        {
          this._added_personas = true;
          yield this._add_personas ();
        }
    }

   /**
   * Add 1 persona and once we've seen it try to re-set it's
   * e-mail address (the Tracker backend should figure it already
   * exist so we don't bump into a constraint error).
   * See https://bugzilla.gnome.org/show_bug.cgi?id=647331 */
  private async void _add_personas ()
    {
      HashTable<string, Value?> details1 = new HashTable<string, Value?>
          (str_hash, str_equal);
      Value? val;

      val = Value (typeof (string));
      val.set_string (this._persona_fullname_1);
      details1.insert (Folks.PersonaStore.detail_key (PersonaDetail.FULL_NAME),
          (owned) val);

      val = Value (typeof (Set));
      var emails1 = new HashSet<EmailFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);
      var email_1 = new EmailFieldDetails (this._email_1);
      emails1.add (email_1);
      val.set_object (emails1);
      details1.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES),
          (owned) val);

     try
        {
          yield this._aggregator.add_persona_from_details (null,
              this._pstore, details1);
        }
      catch (Folks.IndividualAggregatorError e)
        {
          GLib.warning ("[AddPersonaError] add_persona_from_details: %s\n",
              e.message);
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new SetDuplicateEmailTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
