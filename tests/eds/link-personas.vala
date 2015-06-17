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

enum LinkingMethod
{
  IM_ADDRESSES,
  LOCAL_IDS,
  WEB_SERVICE_ADDRESSES,
  EMAIL_AS_IM_ADDRESS
}


public class LinkPersonasTests : EdsTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _persona_fullname_1;
  private string _persona_fullname_2;
  private string _im_address_1 = "someone-1@jabber.example.org";
  private string _im_address_2 = "someone-2@jabber.example.org";
  private string _auto_linkable_email = "the.cool.dude@gmail.tld";
  private bool _linking_fired;
  private bool _persona_found_1;
  private bool _persona_found_2;
  private string _persona_iid_1;
  private string _persona_iid_2;
  private HashSet<Persona> _personas;
  private Gee.HashMap<string, string> _linking_props;
  private LinkingMethod _linking_method;

  public LinkPersonasTests ()
    {
      base ("LinkPersonasTests");

      this.add_test ("test linking personas via IM addresses",
          this.test_linking_personas_via_im_addresses);
      this.add_test ("test linking personas via local IDs",
          this.test_linking_personas_via_local_ids);
      this.add_test ("test linking personas via web service addresses",
          this.test_linking_personas_via_web_service_addresses);
      this.add_test ("test auto linking via e-mail address as IM address",
          this.test_linking_via_email_as_im_address);
    }

  public void test_linking_personas_via_im_addresses ()
    {
      this._linking_method = LinkingMethod.IM_ADDRESSES;
      this._test_linking_personas ();
    }

  public void test_linking_personas_via_local_ids ()
    {
      this._linking_method = LinkingMethod.LOCAL_IDS;
      this._test_linking_personas ();
    }

  public void test_linking_personas_via_web_service_addresses ()
    {
      this._linking_method = LinkingMethod.WEB_SERVICE_ADDRESSES;
      this._test_linking_personas ();
    }

  public void test_linking_via_email_as_im_address ()
    {
      this._linking_method = LinkingMethod.EMAIL_AS_IM_ADDRESS;
      this._test_linking_personas ();
    }

  private void _test_linking_personas ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._persona_fullname_1 = "persona #1";
      this._persona_fullname_2 = "persona #2";
      this._personas = new HashSet<Persona> ();
      this._persona_found_1 = false;
      this._persona_found_2 = false;
      this._linking_fired = false;
      this._persona_iid_1 = "";
      this._persona_iid_2 = "";

      this._linking_props = new Gee.HashMap<string, string> ();
      if (this._linking_method == LinkingMethod.IM_ADDRESSES ||
          this._linking_method == LinkingMethod.WEB_SERVICE_ADDRESSES)
        {
          this._linking_props.set ("prop1", this._im_address_1);
          this._linking_props.set ("prop2", this._im_address_2);
        }
      else if (this._linking_method == LinkingMethod.EMAIL_AS_IM_ADDRESS)
        {
          this._linking_props.set ("prop1", this._auto_linkable_email);
          this._linking_props.set ("prop2", this._auto_linkable_email);
        }

      this._test_linking_personas_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop, 8);

      this._aggregator = null;
      this._main_loop = null;
    }

  private async void _test_linking_personas_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = IndividualAggregator.dup ();
      this._aggregator.individuals_changed_detailed.connect
          (this._individuals_changed_cb);
      try
        {
          yield this._aggregator.prepare ();

          var pstore = this._get_store (store,
              this.eds_backend.address_book_uid);
          assert (pstore != null);

          pstore.notify["is-prepared"].connect (this._notify_pstore_cb);
          if (pstore.is_prepared)
            yield this._add_personas (pstore, pstore);
        }
      catch (GLib.Error e)
        {
          GLib.error ("Error when calling prepare: %s\n", e.message);
        }
    }

  private void _notify_pstore_cb (Object _pstore, ParamSpec ps)
    {
      var pstore = (PersonaStore) _pstore;
      this._add_personas.begin (pstore, pstore);
    }

  private PersonaStore? _get_store (BackendStore store, string store_id)
    {
      PersonaStore? pstore = null;
      foreach (var backend in store.enabled_backends.values)
        {
          pstore = backend.persona_stores.get (store_id);
          if (pstore != null)
            break;
        }
      return pstore;
    }

  /* Here is how this test is expected to work:
   * - we start by adding 2 personas
   * - this should trigger individuals-changed with 2 new individuals
   * - we ask the IndividualAggregator to link the 2 personas coming
   *   from those individuals
   * - we wait for a new Individual which contains the linkable
   *   attributes of these 2 personas
   *
   * @param pstore1 the {@link PersonaStore} in which to add the 1st Persona
   * @param pstore2 the {@link PersonaStore} in which to add the 1st Persona
   */
  private async void _add_personas (PersonaStore pstore1, PersonaStore pstore2)
    {
      HashTable<string, Value?> details1 = new HashTable<string, Value?>
          (str_hash, str_equal);
      Value? v1;
      var wsk =
        Folks.PersonaStore.detail_key (PersonaDetail.WEB_SERVICE_ADDRESSES);

      if (this._linking_method == LinkingMethod.IM_ADDRESSES ||
          this._linking_method == LinkingMethod.EMAIL_AS_IM_ADDRESS)
        {
          v1 = Value (typeof (MultiMap));
          var im_addrs1 = new HashMultiMap<string, ImFieldDetails> (
              null, null, AbstractFieldDetails<string>.hash_static,
              AbstractFieldDetails<string>.equal_static);
          if (this._linking_method == LinkingMethod.EMAIL_AS_IM_ADDRESS)
            im_addrs1.set ("jabber",
                new ImFieldDetails (this._auto_linkable_email));
          else
            im_addrs1.set ("jabber", new ImFieldDetails (this._im_address_1));
          v1.set_object (im_addrs1);
          details1.insert ("im-addresses", (owned) v1);
        }
      else if (this._linking_method == LinkingMethod.WEB_SERVICE_ADDRESSES)
        {
          v1 = Value (typeof (MultiMap));
          var wsa1 = new HashMultiMap<string, WebServiceFieldDetails> (
              null, null, AbstractFieldDetails<string>.hash_static,
              AbstractFieldDetails<string>.equal_static);
          wsa1.set ("twitter", new WebServiceFieldDetails (this._im_address_1));
          v1.set_object (wsa1);
          details1.insert (wsk, (owned) v1);
        }

      Value? v2 = Value (typeof (string));
      v2.set_string (this._persona_fullname_1);
      details1.insert ("full-name", (owned) v2);

      HashTable<string, Value?> details2 = new HashTable<string, Value?>
          (str_hash, str_equal);

      Value? v3;
      if (this._linking_method == LinkingMethod.IM_ADDRESSES)
        {
          v3 = Value (typeof (MultiMap));
          var im_addrs2 = new HashMultiMap<string, ImFieldDetails> (
              null, null, AbstractFieldDetails<string>.hash_static,
              AbstractFieldDetails<string>.equal_static);
          im_addrs2.set ("yahoo", new ImFieldDetails (this._im_address_2));
          v3.set_object (im_addrs2);
          details2.insert ("im-addresses", (owned) v3);
        }
      else if (this._linking_method == LinkingMethod.WEB_SERVICE_ADDRESSES)
        {
          v3 = Value (typeof (MultiMap));
          var wsa2 = new HashMultiMap<string, WebServiceFieldDetails> (
              null, null, AbstractFieldDetails<string>.hash_static,
              AbstractFieldDetails<string>.equal_static);
          wsa2.set ("lastfm", new WebServiceFieldDetails (this._im_address_2));
          v3.set_object (wsa2);
          details2.insert (wsk, (owned) v3);
        }
      else if (this._linking_method == LinkingMethod.EMAIL_AS_IM_ADDRESS)
        {
          v3 = Value (typeof (Set));
          var emails = new HashSet<EmailFieldDetails> (
              AbstractFieldDetails<string>.hash_static,
              AbstractFieldDetails<string>.equal_static);
          var email_1 = new EmailFieldDetails (this._auto_linkable_email);
          emails.add (email_1);
          v3.set_object (emails);
          details2.insert (
              Folks.PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES),
              (owned) v3);
        }

      Value? v4 = Value (typeof (string));
      v4.set_string (this._persona_fullname_2);
      details2.insert ("full-name", (owned)v4);

      try
        {
          yield this._aggregator.add_persona_from_details (null,
              pstore1, details1);

          yield this._aggregator.add_persona_from_details (null,
              pstore2, details2);
        }
      catch (Folks.IndividualAggregatorError e)
        {
          GLib.error ("[AddPersonaError] add_persona_from_details: %s\n",
              e.message);
        }
    }

  private void _individuals_changed_cb (
       MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();

      foreach (var i in added)
        {
          if (i == null)
            {
              continue;
            }

          if (this._linking_method == LinkingMethod.EMAIL_AS_IM_ADDRESS)
            this._check_auto_linked_personas.begin (i);
          else
            this._check_personas.begin (i);
        }
    }

  /* As mentioned in _add_personas here we actually check
   * for the following events
   *
   * - spot the 2 individuals corresponding to the 2 personas we've added
   * - when we've spotted these 2, we pack them in a list and feed that to
   *   IndividualAggregator#link_personas
   * - this should fire a new individuals-changed event with a new individual
   *   which should be the linked individual if it contains the linking
   *   properties of the 2 linked personas.
   */
  private async void _check_personas (Individual i)
    {
      if (this._linking_props.size == 0 &&
          this._linking_fired)
        {
          /* All is done. */
          return;
        }

      Persona first_persona = null;
      foreach (var p in i.personas)
        {
          first_persona = p;
          break;
        }

      if (i.full_name == this._persona_fullname_1 &&
          this._persona_iid_1 == "")
        {
          this._persona_iid_1 = first_persona.iid;
          this._personas.add (first_persona);
          if (this._linking_method == LinkingMethod.LOCAL_IDS)
            {
              var contact_id1 = ((Edsf.Persona) first_persona).iid;
              this._linking_props.set ("prop1", contact_id1);
              debug ("Setting linking prop1 to %s", contact_id1);
            }
        }
      else if (i.full_name == this._persona_fullname_2 &&
          this._persona_iid_2 == "")
        {
          this._persona_iid_2 = first_persona.iid;
          this._personas.add (first_persona);
          if (this._linking_method == LinkingMethod.LOCAL_IDS)
            {
              var contact_id2 = ((Edsf.Persona) first_persona).iid;
              this._linking_props.set ("prop2", contact_id2);
              debug ("Setting linking prop2 to %s", contact_id2);
            }
        }
      else if (i.personas.size > 1)
        {
          /* Lets check if it contains all the linking properties */
          if (this._linking_method == LinkingMethod.IM_ADDRESSES)
            {
              foreach (var proto in i.im_addresses.get_keys ())
                {
                  var im_fds = i.im_addresses.get (proto);
                  foreach (var im_fd in im_fds)
                    {
                      if (im_fd.value == this._linking_props.get ("prop1"))
                        {
                          this._linking_props.unset ("prop1");
                          debug ("Unsetting linking prop1 due to IM address match");
                        }
                      else if (im_fd.value == this._linking_props.get ("prop2"))
                        {
                          this._linking_props.unset ("prop2");
                          debug ("Unsetting linking prop2 due to IM address match");
                        }
                    }
                }
            }
          else if (this._linking_method == LinkingMethod.LOCAL_IDS)
            {
              foreach (var local_id in i.local_ids)
                {
                  debug ("Trying local ID %s", local_id);

                  if (local_id == this._linking_props.get ("prop1"))
                    {
                      this._linking_props.unset ("prop1");
                      debug ("Unsetting linking prop1 due to local ID match");
                    }
                  else if (local_id == this._linking_props.get ("prop2"))
                    {
                      this._linking_props.unset ("prop2");
                      debug ("Unsetting linking prop2 due to local ID match");
                    }
                }
            }
          else if (this._linking_method == LinkingMethod.WEB_SERVICE_ADDRESSES)
            {
              foreach (var service in i.web_service_addresses.get_keys ())
                {
                  var ws_fds = i.web_service_addresses.get (service);
                  foreach (var ws_fd in ws_fds)
                    {
                      var prop1 = this._linking_props.get ("prop1");
                      var prop2 = this._linking_props.get ("prop2");
                      if (prop1 != null &&
                          ws_fd.equal (new WebServiceFieldDetails (prop1)))
                        {
                          this._linking_props.unset ("prop1");
                          debug ("Unsetting linking prop1 due to web service match");
                        }
                      else if (prop2 != null &&
                          ws_fd.equal (new WebServiceFieldDetails (prop2)))
                        {
                          this._linking_props.unset ("prop2");
                          debug ("Unsetting linking prop2 due to web service match");
                        }
                    }
                }
            }

          if (this._linking_props.size == 0)
            {
              debug ("Quitting main loop due to empty linking props set");
              this._main_loop.quit ();
            }
        }

      /* We can try linking the personas only once we've got the
       * 2 initially created personas. */
      if (this._personas.size == 2 &&
          this._linking_fired == false)
        {
          this._linking_fired = true;
          try
            {
              yield this._aggregator.link_personas (this._personas);
            }
          catch (GLib.Error e)
            {
              GLib.error ("link_personas: %s\n", e.message);
            }
        }
    }

  /* Certain e-mail addresses (i.e.: gmail, msn) will be added
   * as IM addresses to their Persona so auto linking should
   * happen.
   *
   * Hence, no need to call link_personas () here.
   */
  private async void _check_auto_linked_personas (Individual i)
    {
      if (this._linking_props.size == 0)
        {
          /* Don't even bother. */
          return;
        }

      if (i.personas.size > 1)
        {
          foreach (var email in i.email_addresses)
            {
              if (email.value == this._auto_linkable_email)
                {
                  this._linking_props.unset ("prop1");
                  debug ("Unsetting linking prop1 due to e-mail address match");
                }
            }

          foreach (var proto1 in i.im_addresses.get_keys ())
            {
              var im_fds1 = i.im_addresses.get (proto1);
              foreach (var im_fd1 in im_fds1)
                {
                  if (im_fd1.value == this._auto_linkable_email)
                    {
                      this._linking_props.unset ("prop2");
                      debug ("Unsetting linking prop2 due to e-mail address match");
                    }
                }
            }
        }

      if (this._linking_props.size == 0)
        {
          debug ("Quitting main loop due to empty linking props set");
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new LinkPersonasTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
