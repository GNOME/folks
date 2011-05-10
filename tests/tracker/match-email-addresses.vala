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

public class MatchEmailAddressesTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private string _persona_fullname_1 = "aaa";
  private string _persona_fullname_2 = "bbb";
  private string _email_1 = "some-address@jabber.example.org";
  private bool _added_personas = false;
  private string _individual_id_1 = "";
  private string _individual_id_2 = "";
  private Folks.MatchResult _match;
  private Trf.PersonaStore _pstore;

  public MatchEmailAddressesTests ()
    {
      base ("MatchEmailAddressesTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test potential match with same email addresses ",
          this.test_match_email_addresses);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
      this._tracker_backend.tear_down ();
    }

  public void test_match_email_addresses ()
    {
      this._main_loop = new GLib.MainLoop (null, false);

      this._test_match_email_addresses_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._match >= Folks.MatchResult.HIGH);
    }

  private async void _test_match_email_addresses_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = new IndividualAggregator ();
      this._aggregator.individuals_changed.connect
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
          this._try_to_add ();
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
          if (i.full_name == this._persona_fullname_1)
            {
              this._individual_id_1 = i.id;
            }
          else if (i.full_name == this._persona_fullname_2)
            {
              this._individual_id_2 = i.id;
            }
        }

      if (this._individual_id_1 != "" &&
          this._individual_id_2 != "")
        {
          this._try_potential_match ();
        }

      assert (removed.size == 0);
    }

  private void _try_potential_match ()
    {
      var ind1 = this._aggregator.individuals.get (this._individual_id_1);
      var ind2 = this._aggregator.individuals.get (this._individual_id_2);

      Folks.PotentialMatch matchObj = new Folks.PotentialMatch ();
      this._match = matchObj.potential_match (ind1, ind2);

      this._main_loop.quit ();
    }

  private void _notify_pstore_cb (Object _pstore, ParamSpec ps)
    {
      this._try_to_add ();
    }

  private async void _try_to_add ()
    {
      lock (this._added_personas)
        {
          if (this._pstore.is_prepared &&
              this._added_personas == false)
            {
              this._added_personas = true;
              yield this._add_personas ();
            }
        }
    }

  private async void _add_personas ()
    {
      HashTable<string, Value?> details1 = new HashTable<string, Value?>
          (str_hash, str_equal);
      HashTable<string, Value?> details2 = new HashTable<string, Value?>
          (str_hash, str_equal);
      Value? val;

      val = Value (typeof (string));
      val.set_string (this._persona_fullname_1);
      details1.insert (Folks.PersonaStore.detail_key (PersonaDetail.FULL_NAME),
          (owned) val);

      val = Value (typeof (Set<FieldDetails>));
      var emails1 = new HashSet<FieldDetails> ();
      var email_1 = new FieldDetails (this._email_1);
      emails1.add (email_1);
      val.set_object (emails1);
      details1.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES),
          (owned) val);

      val = Value (typeof (string));
      val.set_string (this._persona_fullname_2);
      details2.insert (Folks.PersonaStore.detail_key (PersonaDetail.FULL_NAME),
          (owned) val);

      val = Value (typeof (Set<FieldDetails>));
      var emails2 = new HashSet<FieldDetails> ();
      var email_2 = new FieldDetails (this._email_1);
      emails2.add (email_2);
      val.set_object (emails2);
      details2.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES),
          (owned) val);

     try
        {
          yield this._aggregator.add_persona_from_details (null,
              this._pstore, details1);

          yield this._aggregator.add_persona_from_details (null,
              this._pstore, details2);
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

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new MatchEmailAddressesTests ().get_suite ());

  Test.run ();

  return 0;
}