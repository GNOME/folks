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

public class AddPersonaTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private string _persona_nickname;
  private string _family_name;
  private string _given_name;
  private HashTable<string, bool> _properties_found;
  private string _persona_iid;
  private LoadableIcon _avatar;
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
  private string _role_1;
  private PostalAddressFieldDetails _postal_address_fd;
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

      this.add_test ("test adding personas to Tracker ", this.test_add_persona);
    }

  public void test_add_persona ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._persona_fullname = "persona #1";
      this._persona_nickname = "nickname";
      this._family_name = "family";
      this._given_name = "given";
      this._persona_iid = "";
      var _avatar_path = Folks.TestUtils.get_source_test_data (
          "data/avatar-01.jpg");
      this._avatar = new FileIcon (File.new_for_path (_avatar_path));
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
      this._role_1 = "Role";

      var address = new PostalAddress (this._po_box,
          this._extension, this._street, this._locality, this._region,
          this._postal_code, this._country, null, null);
      this._postal_address_fd = new PostalAddressFieldDetails (address);

      TimeVal t = TimeVal ();
      t.from_iso8601 (this._birthday);
      this._bday = new  DateTime.from_timeval_utc (t);

      this._properties_found = new HashTable<string, bool>
          (str_hash, str_equal);
      this._properties_found.insert ("full_name", false);
      this._properties_found.insert ("nickname", false);
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

      this._test_add_persona_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      foreach (var k in this._properties_found.get_values ())
        {
          assert (k);
        }
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
      v2.set_string (this._persona_nickname);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.NICKNAME),
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

      Value? v5 = Value (typeof (LoadableIcon));
      v5.set_object (this._avatar);
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

      Value? v8 = Value (typeof (Set));
      var emails = new HashSet<EmailFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);
      var email_1 = new EmailFieldDetails (this._email_1);
      emails.add (email_1);
      var email_2 = new EmailFieldDetails (this._email_2);
      emails.add (email_2);
      v8.set_object (emails);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES),
          (owned) v8);

      Value? v9 = Value (typeof (MultiMap));
      var im_addrs = new HashMultiMap<string, ImFieldDetails> (null, null,
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);
      im_addrs.set ("jabber", new ImFieldDetails (this._im_addr_1));
      im_addrs.set ("yahoo", new ImFieldDetails (this._im_addr_2));
      v9.set_object (im_addrs);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES), v9);

      Value? v10 = Value (typeof (Set));
      var notes = new HashSet<NoteFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);
      NoteFieldDetails note_fd_1 = new NoteFieldDetails (this._note_1);
      notes.add (note_fd_1);
      v10.set_object (notes);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.NOTES),
          (owned) v10);

      Value? v11 = Value (typeof (Set));
      var phones = new HashSet<PhoneFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

      var phone_1 = new PhoneFieldDetails (this._phone_1);
      phones.add (phone_1);
      var phone_2 = new PhoneFieldDetails (this._phone_2);
      phones.add (phone_2);
      v11.set_object (phones);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.PHONE_NUMBERS),
          (owned) v11);

      Value? v12 = Value (typeof (Set));
      var role_fds = new HashSet<RoleFieldDetails> (
          AbstractFieldDetails<Role>.hash_static,
          AbstractFieldDetails<Role>.equal_static);
      var r1 = new Role (this._title_1, this._organisation_1);
      r1.role = this._role_1;
      var role_fd1 = new RoleFieldDetails (r1);
      role_fds.add (role_fd1);
      v12.set_object (role_fds);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.ROLES),
          (owned) v12);

      Value? v13 = Value (typeof (Set));
      var postal_addresses = new HashSet<PostalAddressFieldDetails> (
          AbstractFieldDetails<PostalAddress>.hash_static,
          AbstractFieldDetails<PostalAddress>.equal_static);

      var postal_a = new PostalAddress (this._po_box,
          this._extension, this._street, this._locality, this._region,
          this._postal_code, this._country, null, null);
      var postal_a_fd = new PostalAddressFieldDetails (postal_a);
      postal_addresses.add (postal_a_fd);
      v13.set_object (postal_addresses);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.POSTAL_ADDRESSES),
          (owned) v13);

      Value? v14 = Value (typeof (Set));
      var urls = new HashSet<UrlFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);
      var url_1 = new UrlFieldDetails (this._url_1);
      urls.add (url_1);
      var url_2 = new UrlFieldDetails (this._url_2);
      urls.add (url_2);
      v14.set_object (urls);
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

  private void _individuals_changed_cb (
       MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();

      foreach (var i in added)
        {
          assert (i != null);

          if (i.is_user == false)
            {
              /* NOTE:
               *   we also listen to the Trf.Persona's structured-name
               *   because if only one of its property is updated
               *   Individual won't fire a notification.
               */
              foreach (var p in i.personas)
                {
                  if (p is NameDetails &&
                      ((NameDetails) p).structured_name != null)
                    {
                      p.notify["structured-name"].connect
                        (this._notify_persona_sname);
                    }
                }

              i.notify["full-name"].connect (this._notify_cb);
              i.notify["nickname"].connect (this._notify_cb);
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
      if (this._pstore.is_prepared && this._added_persona == false)
        {
          this._added_persona = true;
          this._add_persona.begin ();
        }
    }

  private void _check_properties (Individual i)
    {
      if (i.full_name == this._persona_fullname)
        this._properties_found.replace ("full_name", true);

      if (i.nickname == this._persona_nickname)
        this._properties_found.replace ("nickname", true);

      if (i.is_favourite)
        this._properties_found.replace ("is_favourite", true);

      if (i.structured_name != null)
        {
          this._check_sname (i.structured_name);
        }

      if (i.birthday != null &&
          i.birthday.compare (this._bday) == 0)
        this._properties_found.replace ("birthday", true);

      if (i.gender == Gender.MALE)
        this._properties_found.replace ("gender", true);

      foreach (var e in i.email_addresses)
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
              if (a.value == this._im_addr_1)
                this._properties_found.replace ("im-addr-1", true);
              else if (a.value == this._im_addr_2)
                this._properties_found.replace ("im-addr-2", true);
            }
        }

      foreach (var n in i.notes)
        {
          if (n.equal (new NoteFieldDetails (this._note_1)))
            {
              this._properties_found.replace ("note-1", true);
            }
        }

      foreach (var phone_fd in i.phone_numbers)
        {
          if (phone_fd.equal (new PhoneFieldDetails (this._phone_1)))
            {
              this._properties_found.replace ("phone-1", true);
            }
          else if (phone_fd.equal (new PhoneFieldDetails (this._phone_2)))
            {
              this._properties_found.replace ("phone-2", true);
            }
        }

      foreach (var role_fd in i.roles)
        {
          var role_expected = new Role (this._title_1, this._organisation_1);
          role_expected.role = this._role_1;
          var role_fd_expected = new RoleFieldDetails (role_expected);
          if (role_fd.equal (role_fd_expected))
            this._properties_found.replace ("role-1", true);
        }

      foreach (var pafd in i.postal_addresses)
        {
          this._postal_address_fd.id = pafd.id;
          if (pafd.equal (this._postal_address_fd))
            this._properties_found.replace ("postal-address-1", true);
        }

      foreach (var u in i.urls)
        {
          if (u.value == this._url_1)
            this._properties_found.replace ("url-1", true);
          if (u.value == this._url_2)
            this._properties_found.replace ("url-2", true);
        }

      if (i.avatar != null)
        {
          /* arbitrary icon size, but it might as well be on the small side */
          TestUtils.loadable_icons_content_equal.begin (i.avatar,
              this._avatar, 100,
              (obj, result) =>
            {
              if (TestUtils.loadable_icons_content_equal.end (result))
                this._properties_found.replace ("avatar", true);

              this._exit_if_all_properties_found ();
            });
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

  var tests = new AddPersonaTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
