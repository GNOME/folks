/*
 * Copyright (C) 2011 Collabora Ltd.
   Copyright (C) 2013 Canonical Ltd.
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
 *          Renato Araujo Oliveira Filho <renato@canonical.com>
 *          Philip Withnall <philip.withnall@collabora.co.uk>
 *
 */

using Folks;
using Gee;

public class AddPersonaTests : DummyTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private string _persona_nickname;
  private string _email_1;
  private HashTable<string, bool> _properties_found;
  private string _avatar_path;
  private string _im_addr_1;
  private string _im_addr_2;
  private string _phone_1;
  private string _phone_1_type;
  private string _phone_2;
  private string _phone_2_type;
  private PostalAddressFieldDetails _address;
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
  private Individual _individual_received;

  public AddPersonaTests ()
    {
      base ("AddPersonaTests");

      this.add_test ("adding a persona", this.test_add_persona);
    }

  public void test_add_persona ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      this._persona_fullname = "persona #1";
      this._persona_nickname = "Jo";
      this._email_1 = "someone-1@example.org";
      this._avatar_path = Folks.TestUtils.get_source_test_data (
          "data/avatar-01.jpg");
      this._im_addr_1 = "someone-1@jabber.example.org";
      this._im_addr_2 = "someone-2@jabber.example.org";
      this._phone_1 = "12345";
      this._phone_1_type = AbstractFieldDetails.PARAM_TYPE_HOME;
      this._phone_2 = "54321";
      this._phone_2_type = AbstractFieldDetails.PARAM_TYPE_OTHER;
      this._family_name = "family";
      this._given_name = "given";

      var pa = new PostalAddress (this._po_box,
          this._extension, this._street, this._locality, this._region,
          this._postal_code, this._country, null, null);
      this._address = new PostalAddressFieldDetails (pa);
      this._address.add_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_HOME);

      this._properties_found = new HashTable<string, bool>
          (str_hash, str_equal);
      this._properties_found.insert ("full_name", false);
      this._properties_found.insert ("nickname", false);
      this._properties_found.insert ("email-1", false);
      this._properties_found.insert ("avatar", false);
      this._properties_found.insert ("im-addr-1", false);
      this._properties_found.insert ("im-addr-2", false);
      this._properties_found.insert ("phone-1", false);
      this._properties_found.insert ("phone-2", false);
      this._properties_found.insert ("postal-address-1", false);
      this._properties_found.insert ("structured_name", false);
      this._properties_found.insert ("note", false);
      this._properties_found.insert ("birthday", false);
      this._properties_found.insert ("role-1", false);
      this._properties_found.insert ("is-favourite", false);

      this._test_add_persona_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      foreach (var k in this._properties_found.get_values ())
        {
          assert (k);
        }
    }

  private async void _test_add_persona_async ()
    {
      this._aggregator = IndividualAggregator.dup ();
      this._aggregator.individuals_changed_detailed.connect (this._individuals_changed_cb);
      try
        {
          yield this._aggregator.prepare ();
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

      Value? v2 = Value (typeof (Set));
      var emails = new HashSet<EmailFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);
      var email_1 = new EmailFieldDetails (this._email_1);
      email_1.set_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_HOME);
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

      Value? v4 = Value (typeof (MultiMap));
      var im_fds = new HashMultiMap<string, ImFieldDetails> ();
      im_fds.set ("jabber", new ImFieldDetails (this._im_addr_1));
      im_fds.set ("yahoo", new ImFieldDetails (this._im_addr_2));
      v4.set_object (im_fds);
      details.insert (
         Folks.PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES), v4);

      Value? v5 = Value (typeof (Set));
      var phones = new HashSet<PhoneFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

      var phone_1 = new PhoneFieldDetails (this._phone_1);
      phone_1.set_parameter (AbstractFieldDetails.PARAM_TYPE,
          this._phone_1_type);
      phones.add (phone_1);
      var phone_2 = new PhoneFieldDetails (this._phone_2);
      phone_2.set_parameter (AbstractFieldDetails.PARAM_TYPE,
          this._phone_2_type);
      phones.add (phone_2);
      v5.set_object (phones);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.PHONE_NUMBERS),
          (owned) v5);

      Value? v6 = Value (typeof (Set));
      var pa_fds = new HashSet<PostalAddressFieldDetails> (
          AbstractFieldDetails<PostalAddress>.hash_static,
          AbstractFieldDetails<PostalAddress>.equal_static);

      PostalAddress pa_a = new PostalAddress (this._po_box,
          this._extension, this._street, this._locality, this._region,
          this._postal_code, this._country, null, null);
      var pa_fd_a = new PostalAddressFieldDetails (pa_a);
      pa_fd_a.add_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_HOME);
      pa_fds.add (pa_fd_a);
      v6.set_object (pa_fds);
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

      Value? v8 = Value (typeof (Set));
      var notes = new HashSet<NoteFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);
      var note = new NoteFieldDetails (this._note);
      notes.add (note);
      v8.set_object (notes);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.NOTES),
          (owned) v8);

      Value? v9 = Value (typeof (DateTime));
      DateTime dobj = new DateTime.local (1980, 1, 1, 0, 0, 0.0).to_utc ();
      v9.set_boxed (dobj);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.BIRTHDAY),
          (owned) v9);

      Value? v10 = Value (typeof (Set));
      var role_fds = new HashSet<RoleFieldDetails> (
          AbstractFieldDetails<Role>.hash_static,
          AbstractFieldDetails<Role>.equal_static);
      var r1 = new Role ("Dr.", "The Nut House Ltd");
      r1.role = "The Manager";
      var role_fd1 = new RoleFieldDetails (r1);
      role_fds.add (role_fd1);
      v10.set_object (role_fds);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.ROLES),
          (owned) v10);

      Value? v11 = Value (typeof (bool));
      v11.set_boolean (true);
      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.IS_FAVOURITE),
          (owned) v11);

      Value? v12 = Value (typeof (string));
      v12.set_string (this._persona_nickname);
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.NICKNAME),
          (owned) v12);

      try
        {
          yield this._aggregator.add_persona_from_details (null,
              this.dummy_persona_store, details);
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

      uint num_replaces = 0;

      foreach (var i in added)
        {
          if (i == null)
            {
              continue;
            }

          num_replaces = this._track_individual (i);
        }

      assert (removed.size <= num_replaces + 1);
    }

  private uint _track_individual (Individual i)
    {
      uint retval = 0;

      if (i.is_user == false)
        {
          /* we assume that there will be exactly one (unique) individual
           * received */
          assert (this._individual_received == null ||
              this._individual_received.id == i.id);

          /* handle replacement */
          if (this._individual_received != null)
            {
              i.notify.disconnect (this._notify_cb);

              this._properties_found.remove_all ();
            }

          this._individual_received = i;
          retval++;

          i.notify.connect (this._notify_cb);

          this._check_properties.begin (i);
        }

      return retval;
    }

  private void _notify_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      this._check_properties.begin (i);
    }

  private void _try_to_add ()
    {
      this._add_persona.begin ();
    }

  private async void _check_properties (Individual i)
    {
      if (i.full_name == this._persona_fullname)
        this._properties_found.replace ("full_name", true);

      if (i.nickname == this._persona_nickname)
        {
          this._properties_found.replace ("nickname", true);
        }

      foreach (var e in i.email_addresses)
        {
          if (e.value == this._email_1)
            {
              this._properties_found.replace ("email-1", true);
            }
        }

      foreach (var proto in i.im_addresses.get_keys ())
        {
          var im_fds = i.im_addresses.get (proto);
          foreach (var im_fd in im_fds)
            {
              if (im_fd.value == this._im_addr_1)
                this._properties_found.replace ("im-addr-1", true);
              else if (im_fd.value == this._im_addr_2)
                this._properties_found.replace ("im-addr-2", true);
            }
        }

      foreach (var phone_fd in i.phone_numbers)
        {
          var phone_1 = new PhoneFieldDetails (this._phone_1);
          phone_1.set_parameter (AbstractFieldDetails.PARAM_TYPE,
              this._phone_1_type);
          var phone_2 = new PhoneFieldDetails (this._phone_2);
          phone_2.set_parameter (AbstractFieldDetails.PARAM_TYPE,
              this._phone_2_type);

          if (phone_fd.equal (phone_1))
            {
              this._properties_found.replace ("phone-1", true);
            }
          else if (phone_fd.equal (phone_2))
            {
              this._properties_found.replace ("phone-2", true);
            }
        }

      foreach (var pa_fd in i.postal_addresses)
        {
          this._address.id = pa_fd.id;
          if (pa_fd.equal (this._address))
            this._properties_found.replace ("postal-address-1", true);
        }

      if (i.structured_name != null &&
          i.structured_name.family_name == this._family_name &&
          i.structured_name.given_name == this._given_name)
        this._properties_found.replace ("structured_name", true);

      foreach (var note in i.notes)
        {
          if (note.equal (new NoteFieldDetails (this._note)))
            {
              this._properties_found.replace ("note", true);
              break;
            }
        }

      if (i.avatar != null)
        {
          var b = new FileIcon (File.new_for_path (this._avatar_path));

          var same = yield TestUtils.loadable_icons_content_equal (b, i.avatar,
              -1);
          if (same)
            this._properties_found.replace ("avatar", true);
        }

      if (i.birthday != null)
        {
          DateTime dobj = new DateTime.local (1980, 1, 1, 0, 0, 0.0).to_utc ();
          if (i.birthday.equal (dobj)) {
            this._properties_found.replace ("birthday", true);
          }
        }

      foreach (var role_fd in i.roles)
        {
          var r1 = new Role ("Dr.", "The Nut House Ltd");
          r1.role = "The Manager";
          var role_fd_expected = new RoleFieldDetails (r1);
          if (role_fd.equal (role_fd_expected))
            this._properties_found.replace ("role-1", true);
        }

      if (i.is_favourite)
        {
          this._properties_found.replace ("is-favourite", true);
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

  var tests = new AddPersonaTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
