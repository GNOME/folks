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

public class AddPersonaTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private EdsTest.Backend _eds_backend;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private string _email_1;
  private Edsf.PersonaStore _pstore;
  private bool _added_persona = false;
  private HashTable<string, bool> _properties_found;
  private string _avatar_path;
  private string _im_addr_1;
  private string _im_addr_2;
  private string _phone_1;
  private string _phone_2;
  private PostalAddress _address;
  private string _po_box = "12345";
  private string _locality = "locality";
  private string _postal_code = "code";
  private string _street = "some street";
  private string _extension = "some extension";
  private string _country = "some country";
  private string _region = "some region";
  private string _family_name;
  private string _given_name;
  private string _note = "This is a note.";

  public AddPersonaTests ()
    {
      base ("AddPersonaTests");

      this._eds_backend = new EdsTest.Backend ();

      this.add_test ("test adding a persona to e-d-s ", this.test_add_persona);
    }

  public override void set_up ()
    {
      this._eds_backend.set_up ();
    }

  public override void tear_down ()
    {
      this._eds_backend.tear_down ();
    }

  public void test_add_persona ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._persona_fullname = "persona #1";
      this._email_1 = "someone-1@example.org";
      this._avatar_path = Environment.get_variable ("AVATAR_FILE_PATH");
      this._im_addr_1 = "someone-1@jabber.example.org";
      this._im_addr_2 = "someone-2@jabber.example.org";
      this._phone_1 = "12345";
      this._phone_2 = "54321";
      this._family_name = "family";
      this._given_name = "given";

      var types =  new HashSet<string> ();
      types.add (Edsf.Persona.address_fields[0]);
      this._address = new PostalAddress (this._po_box,
          this._extension, this._street, this._locality, this._region,
          this._postal_code, this._country, null, types, null);

      this._properties_found = new HashTable<string, bool>
          (str_hash, str_equal);
      this._properties_found.insert ("full_name", false);
      this._properties_found.insert ("email-1", false);
      this._properties_found.insert ("avatar", false);
      this._properties_found.insert ("im-addr-1", false);
      this._properties_found.insert ("im-addr-2", false);
      this._properties_found.insert ("phone-1", false);
      this._properties_found.insert ("phone-2", false);
      this._properties_found.insert ("postal-address-1", false);
      this._properties_found.insert ("structured_name", false);
      this._properties_found.insert ("note", false);

      this._test_add_persona_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      foreach (var k in this._properties_found.get_values ())
        {
          assert (k);
        }
    }

  private async void _test_add_persona_async ()
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
                (Edsf.PersonaStore) backend.persona_stores.get ("local://test");
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

  private async void _add_persona ()
    {
      HashTable<string, Value?> details = new HashTable<string, Value?>
          (str_hash, str_equal);

      Value? v1 = Value (typeof (string));
      v1.set_string (this._persona_fullname);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.FULL_NAME),
          (owned) v1);

      Value? v2 = Value (typeof (Set<FieldDetails>));
      var emails = new HashSet<FieldDetails> ();
      var email_1 = new FieldDetails (this._email_1);
      email_1.set_parameter ("type", Edsf.Persona.email_fields[0]);
      emails.add (email_1);
      v2.set_object (emails);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES),
          (owned) v2);

      Value? v3 = Value (typeof (LoadableIcon));
      var avatar = new FileIcon (File.new_for_path (this._avatar_path));
      v3.set_object (avatar);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.AVATAR),
          (owned) v3);

      Value? v4 = Value (typeof (MultiMap<string, string>));
      var im_addrs = new HashMultiMap<string, string> ();
      im_addrs.set ("jabber", this._im_addr_1);
      im_addrs.set ("yahoo", this._im_addr_2);
      v4.set_object (im_addrs);
      details.insert (
         Folks.PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES), v4);

      Value? v5 = Value (typeof (Set<FieldDetails>));
      var phones = new HashSet<FieldDetails> ();
      var phone_1 = new FieldDetails (this._phone_1);
      phone_1.set_parameter ("type", Edsf.Persona.phone_fields[0]);
      phones.add (phone_1);
      var phone_2 = new FieldDetails (this._phone_2);
      phone_2.set_parameter ("type", Edsf.Persona.phone_fields[1]);
      phones.add (phone_2);
      v5.set_object (phones);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.PHONE_NUMBERS),
          (owned) v5);

      Value? v6 = Value (typeof (Set<PostalAddress>));
      var postal_addresses = new HashSet<PostalAddress> ();

      var types =  new HashSet<string> ();
      types.add (Edsf.Persona.address_fields[0]);
      PostalAddress postal_a = new PostalAddress (this._po_box,
          this._extension, this._street, this._locality, this._region,
          this._postal_code, this._country, null, types, null);
      postal_addresses.add (postal_a);
      v6.set_object (postal_addresses);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.POSTAL_ADDRESSES),
          (owned) v6);

      Value? v7 = Value (typeof (StructuredName));
      StructuredName sname = new StructuredName (this._family_name,
          this._given_name, null, null, null);
      v7.set_object (sname);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.STRUCTURED_NAME),
          (owned) v7);

      Value? v8 = Value (typeof (Set<Note>));
      var notes = new HashSet<Note> ();
      var note = new Note(this._note);
      notes.add (note);
      v8.set_object (notes);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.NOTES),
          (owned) v8);

      try
        {
          yield this._aggregator.add_persona_from_details (null,
              this._pstore, details);
        }
      catch (Folks.IndividualAggregatorError e)
        {
          GLib.warning ("[AddPersonaError] add_persona_from_details: %s\n",
              e.message);
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
          if (i.is_user == false)
            {
              i.notify["full-name"].connect (this._notify_cb);
              i.notify["email-addresses"].connect (this._notify_cb);
              i.notify["avatar"].connect (this._notify_cb);
              i.notify["im-addresses"].connect (this._notify_cb);
              i.notify["phone-numbers"].connect (this._notify_cb);
              i.notify["postal-addresses"].connect (this._notify_cb);
              i.notify["structured-name"].connect (this._notify_cb);
              i.notify["notes"].connect (this._notify_cb);

              this._check_properties (i);
            }
        }

      assert (removed.size == 0);
    }

  private void _notify_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      this._check_properties (i);
    }

  private void _notify_pstore_cb (Object _pstore, ParamSpec ps)
    {
      this._try_to_add ();
    }

  private void _try_to_add ()
    {
      lock (this._added_persona)
        {
          if (this._pstore.is_prepared &&
              this._added_persona == false)
            {
              this._added_persona = true;
              this._add_persona ();
            }
        }
    }

  private void _check_properties (Individual i)
    {
      if (i.full_name == this._persona_fullname)
        this._properties_found.replace ("full_name", true);

      foreach (var e in i.email_addresses)
        {
          if (e.value == this._email_1)
            {
              this._properties_found.replace ("email-1", true);
            }
        }

      if (i.avatar != null)
        {
          var b = new FileIcon (File.new_for_path (this._avatar_path));

          if (b.equal (i.avatar) == true)
            {
              this._properties_found.replace ("avatar", true);
            }
        }

      foreach (var proto in i.im_addresses.get_keys ())
        {
          var addrs = i.im_addresses.get (proto);
          foreach (var a in addrs)
            {
              if (a == this._im_addr_1)
                this._properties_found.replace ("im-addr-1", true);
              else if (a == this._im_addr_2)
                this._properties_found.replace ("im-addr-2", true);
            }
        }

      foreach (var e in i.phone_numbers)
        {
          if (e.value == this._phone_1)
            {
              this._properties_found.replace ("phone-1", true);
            }
          else if (e.value == this._phone_2)
            {
              this._properties_found.replace ("phone-2", true);
            }
        }

      foreach (var pa in i.postal_addresses)
        {
          this._address.uid = pa.uid;
          if (pa.equal (this._address))
            this._properties_found.replace ("postal-address-1", true);
        }

      if (i.structured_name != null &&
          i.structured_name.family_name == this._family_name &&
          i.structured_name.given_name == this._given_name)
        this._properties_found.replace ("structured_name", true);

      foreach (var note in i.notes)
        {
          if (note.content == this._note)
            {
              this._properties_found.replace ("note", true);
              break;
            }
        }

      this._exit_if_all_properties_found ();
    }

  private void _exit_if_all_properties_found ()
    {
      foreach (var k in this._properties_found.get_keys ())
        {
          var v = this._properties_found.lookup (k);
          if (v == false)
            return;
        }
      this._main_loop.quit ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new AddPersonaTests ().get_suite ());

  Test.run ();

  return 0;
}
