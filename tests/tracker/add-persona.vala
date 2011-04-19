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

public class AddPersonaTests : Folks.TestCase
{
  private GLib.MainLoop _main_loop;
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private string _persona_alias;
  private string _family_name;
  private string _given_name;
  private HashTable<string, bool> _properties_found;
  private string _persona_iid;
  private string _file_uri;
  private string _birthday;
  private DateTime _bday;
  private string _email_1;
  private string _email_2;
  private string _im_addr_1;
  private string _im_addr_2;
  private string _note_1;
  private string _phone_1;
  private string _phone_2;
  private string _title_1;
  private string _organisation_1;
  private PostalAddress _address;
  private string _po_box = "12345";
  private string _locality = "locality";
  private string _postal_code = "code";
  private string _street = "some street";
  private string _extension = "some extension";
  private string _country = "some country";
  private string _region = "some region";
  private string _url_1 = "http://www-1.example.org";
  private string _url_2 = "http://www-1.example.org";
  private Trf.PersonaStore _pstore;
  private bool _added_persona = false;

  public AddPersonaTests ()
    {
      base ("AddPersonaTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test adding personas to Tracker ", this.test_add_persona);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_add_persona ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._persona_fullname = "persona #1";
      this._persona_alias = "alias";
      this._family_name = "family";
      this._given_name = "given";
      this._persona_iid = "";
      this._file_uri = "file:///tmp/some-avatar.jpg";
      this._birthday = "2001-10-26T20:32:52Z";
      this._email_1 = "someone-1@example.org";
      this._email_2 = "someone-2@example.org";
      this._im_addr_1 = "someone-1@jabber.example.org";
      this._im_addr_2 = "someone-2@jabber.example.org";
      this._note_1 = "this is a note";
      this._phone_1 = "12345";
      this._phone_2 = "54321";
      this._title_1 = "CFO";
      this._organisation_1 = "Example Inc.";

      GLib.List<string> types =  new GLib.List<string> ();
      this._address = new PostalAddress (this._po_box,
          this._extension, this._street, this._locality, this._region,
          this._postal_code, this._country, null, types, null);

      TimeVal t = TimeVal ();
      t.from_iso8601 (this._birthday);
      this._bday = new  DateTime.from_timeval_utc (t);

      this._properties_found = new HashTable<string, bool>
          (str_hash, str_equal);
      this._properties_found.insert ("full_name", false);
      this._properties_found.insert ("alias", false);
      this._properties_found.insert ("is_favourite", false);
      this._properties_found.insert ("structured_name", false);
      this._properties_found.insert ("avatar", false);
      this._properties_found.insert ("birthday", false);
      this._properties_found.insert ("gender", false);
      this._properties_found.insert ("email-1", false);
      this._properties_found.insert ("email-2", false);
      this._properties_found.insert ("im-addr-1", false);
      this._properties_found.insert ("im-addr-2", false);
      this._properties_found.insert ("note-1", false);
      this._properties_found.insert ("phone-1", false);
      this._properties_found.insert ("phone-2", false);
      this._properties_found.insert ("role-1", false);
      this._properties_found.insert ("postal-address-1", false);
      this._properties_found.insert ("url-1", false);
      this._properties_found.insert ("url-2", false);

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

      this._tracker_backend.tear_down ();
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
          foreach (var backend in store.enabled_backends)
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

  private async void _add_persona ()
    {
      HashTable<string, Value?> details = new HashTable<string, Value?>
          (str_hash, str_equal);

      Value? v1 = Value (typeof (string));
      v1.set_string (this._persona_fullname);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.FULL_NAME),
          (owned) v1);

      Value? v2 = Value (typeof (string));
      v2.set_string (this._persona_alias);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.ALIAS),
          (owned) v2);

      Value? v3 = Value (typeof (bool));
      v3.set_boolean (true);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.IS_FAVOURITE),
          (owned) v3);

      Value? v4 = Value (typeof (StructuredName));
      StructuredName sname = new StructuredName (this._family_name,
          this._given_name, null, null, null);
      v4.set_object (sname);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.STRUCTURED_NAME),
          (owned) v4);

      Value? v5 = Value (typeof (File));
      File avatar = File.new_for_uri (this._file_uri);
      v5.set_object (avatar);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.AVATAR),
          (owned) v5);

      Value? v6 = Value (typeof (DateTime));
      TimeVal t = TimeVal ();
      t.from_iso8601 (this._birthday);
      DateTime dobj = new  DateTime.from_timeval_utc (t);
      v6.set_boxed (dobj);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.BIRTHDAY),
          (owned) v6);

      Value? v7 = Value (typeof (Folks.Gender));
      v7.set_enum (Folks.Gender.MALE);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.GENDER),
          (owned) v7);

      Value? v8 = Value (typeof (GLib.List<FieldDetails>));
      GLib.List<FieldDetails> emails =
        new GLib.List<FieldDetails> ();
      var email_1 = new FieldDetails (this._email_1);
      emails.prepend ((owned) email_1);
      var email_2 = new FieldDetails (this._email_2);
      emails.prepend ((owned) email_2);
      v8.set_pointer (emails);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES),
          (owned) v8);

      Value? v9 = Value (typeof (MultiMap<string, string>));
      var im_addrs = new HashMultiMap<string, string> ();
      im_addrs.set ("jabber", this._im_addr_1);
      im_addrs.set ("yahoo", this._im_addr_2);
      v9.set_object (im_addrs);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES), v9);

      Value? v10 = Value (typeof (Gee.HashSet<Note>));
      Gee.HashSet<Note> notes = new Gee.HashSet<Note> ();
      Note n1 = new Note (this._note_1);
      notes.add (n1);
      v10.set_object (notes);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.NOTES),
          (owned) v10);

      Value? v11 = Value (typeof (GLib.List<FieldDetails>));
      GLib.List<FieldDetails> phones =
        new GLib.List<FieldDetails> ();
      var phone_1 = new FieldDetails (this._phone_1);
      phones.prepend ((owned) phone_1);
      var phone_2 = new FieldDetails (this._phone_2);
      phones.prepend ((owned) phone_2);
      v11.set_pointer (phones);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.PHONE_NUMBERS),
          (owned) v11);

      Value? v12 = Value (typeof (Gee.HashSet<Role>));
      Gee.HashSet<Role> roles = new Gee.HashSet<Role> ();
      Role r1 = new Role (this._title_1, this._organisation_1);
      roles.add (r1);
      v12.set_object (roles);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.ROLES),
          (owned) v12);

      Value? v13 = Value (typeof (Set<PostalAddress>));
      var postal_addresses = new HashSet<PostalAddress> ();

      GLib.List<string> types =  new GLib.List<string> ();
      PostalAddress postal_a = new PostalAddress (this._po_box,
          this._extension, this._street, this._locality, this._region,
          this._postal_code, this._country, null, types, null);
      postal_addresses.add (postal_a);
      v13.set_object (postal_addresses);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.POSTAL_ADDRESSES),
          (owned) v13);

      Value? v14 = Value (typeof (GLib.List<FieldDetails>));
      GLib.List<FieldDetails> urls =
        new GLib.List<FieldDetails> ();
      var url_1 = new FieldDetails (this._url_1);
      urls.prepend ((owned) url_1);
      var url_2 = new FieldDetails (this._url_2);
      urls.prepend ((owned) url_2);
      v14.set_pointer (urls);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.URLS),
          (owned) v14);

      try
        {
          Trf.Persona persona = (Trf. Persona)
              yield this._aggregator.add_persona_from_details
                (null, this._pstore, details);
          this._persona_iid = persona.iid;
        }
      catch (Folks.IndividualAggregatorError e)
        {
          GLib.warning ("[AddPersonaError] add_persona_from_details: %s\n",
              e.message);
        }
    }

  private void _individuals_changed_cb
      (GLib.List<Individual>? added,
       GLib.List<Individual>? removed,
       string? message,
       Persona? actor,
       GroupDetails.ChangeReason reason)
    {
      foreach (unowned Individual i in added)
        {
          if (i.is_user == false)
            {
              /* NOTE:
               *   we also listen to the Trf.Persona's structured-name
               *   because if only one of its property is updated
               *   Individual won't fire a notification.
               */
              unowned Trf.Persona p = (Trf.Persona) i.personas.nth_data (0);
              if (p.structured_name != null)
                {
                  p.notify["structured-name"].connect
                    (this._notify_persona_sname);
                }

              i.notify["full-name"].connect (this._notify_cb);
              i.notify["alias"].connect (this._notify_cb);
              i.notify["avatar"].connect (this._notify_cb);
              i.notify["is-favourite"].connect (this._notify_cb);
              i.notify["structured-name"].connect (this._notify_cb);
              i.notify["family-name"].connect (this._notify_cb);
              i.notify["given-name"].connect (this._notify_cb);
              i.notify["avatar"].connect (this._notify_cb);
              i.notify["birthday"].connect (this._notify_cb);
              i.notify["gender"].connect (this._notify_cb);
              i.notify["email-addresses"].connect (this._notify_cb);
              i.notify["im-addresses"].connect (this._notify_cb);
              i.notify["notes"].connect (this._notify_cb);
              i.notify["phone-numbers"].connect (this._notify_cb);
              i.notify["roles"].connect (this._notify_cb);
              i.notify["postal-addresses"].connect (this._notify_cb);
              i.notify["urls"].connect (this._notify_cb);

              this._check_properties (i);
            }
        }

      assert (removed == null);
    }

  private void _notify_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      this._check_properties (i);
    }

  private void _notify_persona_sname (Object persona_p, ParamSpec ps)
    {
      Trf.Persona persona = (Trf.Persona) persona_p;
      this._check_sname (persona.structured_name);
      this._exit_if_all_properties_found ();
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

      if (i.alias == this._persona_alias)
        this._properties_found.replace ("alias", true);

      if (i.is_favourite)
        this._properties_found.replace ("is_favourite", true);

      if (i.structured_name != null)
        {
          this._check_sname (i.structured_name);
        }

      if (i.avatar != null &&
          i.avatar.get_uri () == this._file_uri)
        this._properties_found.replace ("avatar", true);

      if (i.birthday != null &&
          i.birthday.compare (this._bday) == 0)
        this._properties_found.replace ("birthday", true);

      if (i.gender == Gender.MALE)
        this._properties_found.replace ("gender", true);

      foreach (unowned FieldDetails e in i.email_addresses)
        {
          if (e.value == this._email_1)
            {
              this._properties_found.replace ("email-1", true);
            }
          else if (e.value == this._email_2)
            {
              this._properties_found.replace ("email-2", true);
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

      foreach (var n in i.notes)
        {
          if (n.content == this._note_1)
            {
              this._properties_found.replace ("note-1", true);
            }
        }

      foreach (unowned FieldDetails e in i.phone_numbers)
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

      foreach (var r in i.roles)
        {
          if (r.title == this._title_1 &&
              r.organisation_name == this._organisation_1)
            {
              this._properties_found.replace ("role-1", true);
            }
        }

      foreach (var pa in i.postal_addresses)
        {
          this._address.uid = pa.uid;
          if (pa.equal (this._address))
            this._properties_found.replace ("postal-address-1", true);
        }

      foreach (var u in i.urls)
        {
          if (u.value == this._url_1)
            this._properties_found.replace ("url-1", true);
          if (u.value == this._url_2)
            this._properties_found.replace ("url-2", true);
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

  private void _check_sname (StructuredName sname)
    {
      if (sname.family_name == this._family_name &&
          sname.given_name == this._given_name)
        this._properties_found.replace ("structured_name", true);
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
