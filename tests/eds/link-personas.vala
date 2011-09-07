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
  LOCAL_IDS_DIFF_STORES
}


public class LinkPersonasTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private EdsTest.Backend? _eds_backend;
  private EdsTest.Backend? _eds_backend_other;
  private IndividualAggregator _aggregator;
  private string _persona_fullname_1;
  private string _persona_fullname_2;
  private string _im_address_1 = "someone-1@jabber.example.org";
  private string _im_address_2 = "someone-2@jabber.example.org";
  private bool _linking_fired;
  private bool _persona_found_1;
  private bool _persona_found_2;
  private string _persona_iid_1;
  private string _persona_iid_2;
  private HashSet<Persona> _personas;
  private int _removed_individuals;
  private string _folks_config_key = "/system/folks/backends/primary_store";
  private unowned GConf.Client? _gconf_client;
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
      this.add_test ("test linking via local IDs using different PersonaStores",
          this.test_linking_via_local_ids_diff_stores);
    }

  public override void set_up ()
    {
      this._eds_backend = new EdsTest.Backend ();
      this._eds_backend_other = new EdsTest.Backend ();
      this._eds_backend_other.address_book_uri = "local://other";

      /* We configure eds as the primary (writeable) store */
      this._gconf_client = GConf.Client.get_default ();
      try
        {
          GConf.Value val = new GConf.Value (GConf.ValueType.STRING);
          val.set_string ("eds:%s".printf (this._eds_backend.address_book_uri));
          this._gconf_client.set (this._folks_config_key, val);
        }
      catch (GLib.Error e)
        {
          warning ("Couldn't set primary store: %s\n", e.message);
        }

      this._eds_backend.set_up ();
      this._eds_backend_other.set_up ();
    }

  public override void tear_down ()
    {
      this._eds_backend.tear_down ();
      this._eds_backend_other.tear_down ();

      this._eds_backend = null;
      this._eds_backend_other = null;

      try
        {
          this._gconf_client.unset (this._folks_config_key);
        }
      catch (GLib.Error e)
        {
          warning ("Couldn't unset primary store: %s\n", e.message);
        }
      finally
        {
          this._gconf_client = null;
        }
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

  public void test_linking_via_local_ids_diff_stores ()
    {
      this._linking_method = LinkingMethod.LOCAL_IDS_DIFF_STORES;
      this._test_linking_personas ();
    }

  private void _test_linking_personas ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._persona_fullname_1 = "persona #1";
      this._persona_fullname_2 = "persona #2";
      this._personas = new HashSet<Persona> ();
      this._removed_individuals = 0;
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

      this._test_linking_personas_async ();

      var timer_id = Timeout.add_seconds (8, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      /* Check we get the new individual (containing the linked
       * personas) and that the previous ones were removed. */
      assert (this._linking_props.size == 0);
      assert (this._removed_individuals == 2);

      GLib.Source.remove (timer_id);
      this._aggregator = null;
      this._main_loop = null;
    }

  private async void _test_linking_personas_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = new IndividualAggregator ();
      this._aggregator.individuals_changed_detailed.connect
          (this._individuals_changed_cb);
      try
        {
          yield this._aggregator.prepare ();

          var pstore = this._get_store (store, "local://test");

          assert (pstore != null);

          if (this._linking_method == LinkingMethod.LOCAL_IDS_DIFF_STORES)
            {
              var pstore2 = this._get_store (store,
                  this._eds_backend_other.address_book_uri);
              assert (pstore2 != null);
              yield this._add_personas (pstore, pstore2);
            }
          else
            yield this._add_personas (pstore, pstore);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }
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

      if (this._linking_method == LinkingMethod.IM_ADDRESSES)
        {
          v1 = Value (typeof (MultiMap<string,  ImFieldDetails>));
          var im_addrs1 = new HashMultiMap<string, ImFieldDetails> (
              null, null,
              (GLib.HashFunc) ImFieldDetails.hash,
              (GLib.EqualFunc) ImFieldDetails.equal);
          im_addrs1.set ("jabber", new ImFieldDetails (this._im_address_1));
          v1.set_object (im_addrs1);
          details1.insert ("im-addresses", (owned) v1);
        }
      else if (this._linking_method == LinkingMethod.WEB_SERVICE_ADDRESSES)
        {
          v1 = Value (typeof (MultiMap<string, WebServiceFieldDetails>));
          var wsa1 = new HashMultiMap<string, WebServiceFieldDetails> (
              null, null,
              (GLib.HashFunc) WebServiceFieldDetails.hash,
              (GLib.EqualFunc) WebServiceFieldDetails.equal);
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
          v3 = Value (typeof (MultiMap<string, string>));
          var im_addrs2 = new HashMultiMap<string, ImFieldDetails> (
              null, null,
              (GLib.HashFunc) ImFieldDetails.hash,
              (GLib.EqualFunc) ImFieldDetails.equal);
          im_addrs2.set ("yahoo", new ImFieldDetails (this._im_address_2));
          v3.set_object (im_addrs2);
          details2.insert ("im-addresses", (owned) v3);
        }
      else if (this._linking_method == LinkingMethod.WEB_SERVICE_ADDRESSES)
        {
          v3 = Value (typeof (MultiMap<string, WebServiceFieldDetails>));
          var wsa2 = new HashMultiMap<string, WebServiceFieldDetails> (
              null, null,
              (GLib.HashFunc) WebServiceFieldDetails.hash,
              (GLib.EqualFunc) WebServiceFieldDetails.equal);
          wsa2.set ("lastfm", new WebServiceFieldDetails (this._im_address_2));
          v3.set_object (wsa2);
          details2.insert (wsk, (owned) v3);
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
          GLib.warning ("[AddPersonaError] add_persona_from_details: %s\n",
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

          this._check_personas (i);
        }

      foreach (var i in removed)
        {
          if (i != null)
            {
              this._removed_individuals++;
            }
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
                        }
                      else if (im_fd.value == this._linking_props.get ("prop2"))
                        {
                          this._linking_props.unset ("prop2");
                        }
                    }
                }
            }
          else if (this._linking_method == LinkingMethod.LOCAL_IDS)
            {
              foreach (var local_id in i.local_ids)
                {
                  if (local_id == this._linking_props.get ("prop1"))
                    {
                      this._linking_props.unset ("prop1");
                    }
                  else if (local_id == this._linking_props.get ("prop2"))
                    {
                      this._linking_props.unset ("prop2");
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
                        }
                      else if (prop2 != null &&
                          ws_fd.equal (new WebServiceFieldDetails (prop2)))
                        {
                          this._linking_props.unset ("prop2");
                        }
                    }
                }
            }

          if (this._linking_props.size == 0)
            {
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
              GLib.warning ("link_personas: %s\n", e.message);
            }
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new LinkPersonasTests ().get_suite ());

  Test.run ();

  return 0;
}
