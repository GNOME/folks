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

using E;
using Folks;
using Random;

errordomain EdsTest.BackendSetupError
{
  FETCH_SOURCE_GROUP_FAILED,
  OPENING_FAILED,
  ADD_CONTACT_FAILED,
  ADD_TO_SOURCE_GROUP_FAILED,
}

public class EdsTest.Backend
{
  private string _addressbook_name;
  private E.BookClient? _addressbook = null;
  private string[] _e_contacts;
  private GLib.List<Gee.HashMap<string, Value?>> _contacts;
  E.SourceRegistry? _source_registry = null;
  E.Source? _source = null;
  File? _source_file = null;

  public string address_book_uid
    {
      get { return this._addressbook.get_source ().get_uid (); }
    }

  public Backend (string name = "test")
    {
      this._contacts = new GLib.List<Gee.HashMap<string, Value?>> ();
      this._e_contacts = new string[0];
      this._addressbook_name = name;
    }

  public void add_contact (owned Gee.HashMap<string, Value?> c)
    {
      this._contacts.prepend (c);
    }

  public async void update_contact (int contact_pos,
      owned Gee.HashMap<string, Value?> updated_data)
    {
      var uid = this._e_contacts[contact_pos];
      E.Contact contact;
      try
        {
          yield this._addressbook.get_contact (uid, null, out contact);
          this._set_contact_fields (contact, updated_data);
          yield this._addressbook.modify_contact (contact, E.BookOperationFlags.NONE, null);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Couldn't update contact\n");
        }
    }

  public async void remove_contact (int contact_pos)
    {
      var uid = this._e_contacts[contact_pos];
      E.Contact contact;
      try
        {
          yield this._addressbook.get_contact (uid, null, out contact);
          yield this._addressbook.remove_contact (contact, E.BookOperationFlags.NONE, null);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Couldn't remove contact\n");
        }
    }

  public void reset ()
    {
      this._contacts = new GLib.List<Gee.HashMap<string, Value?>> ();
      this._e_contacts = new string[0];
    }

  /* Create a temporary addressbook */
  public void set_up (bool source_is_default = false)
    {
      try
        {
          this._prepare_source (source_is_default);
          this._addressbook = BookClient.connect_sync (this._source, 1, null);
          Environment.set_variable ("FOLKS_BACKEND_EDS_USE_ADDRESS_BOOKS",
                                    this._addressbook_name, true);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Unable to create test data: %s\n", e.message);
        }
    }

  public void set_as_default ()
    {
      this._source_registry.set_default_address_book (this._source);
    }

  private void _prepare_source (bool is_default)
    {
      var mainloop = new GLib.MainLoop (null, false);

      this._prepare_source_async.begin (is_default, (obj, async_res) =>
        {
          try
            {
              this._prepare_source_async.end (async_res);
              mainloop.quit ();
            }
          catch (GLib.Error e)
            {
              GLib.critical (e.message);
            }
        });

      mainloop.run ();
    }

  private async void _prepare_source_async (bool is_default) throws GLib.Error
    {
      /* Create a new source file. */
      var source_file_name = this._addressbook_name + ".source";

      var config_dir = File.new_for_path (Environment.get_user_config_dir ());
      var source_file = config_dir.get_child ("evolution")
          .get_child ("sources").get_child (source_file_name);

      var source_file_content = ("[Data Source]\n" +
          "DisplayName=%s\n" +
          "Enabled=true\n" +
          "Parent=local-stub\n" +
          "\n" +
          "[Address Book]\n" +
          "BackendName=local\n").printf (this._addressbook_name);

      yield source_file.replace_contents_async (source_file_content.data, null,
          false, FileCreateFlags.NONE, null, null);

      /* Build a SourceRegistry to manage the sources. */
      var source_registry = yield new E.SourceRegistry (null);
      this._source_registry = source_registry;
      var signal_id = source_registry.source_added.connect ((r, s) =>
        {
          if (s.uid != this._addressbook_name)
              return;

          this._source = s;
          this._prepare_source_async.callback ();
        });

      /* Wait for the SourceRegistry to notify if it hasn’t already. */
      this._source = source_registry.ref_source (this._addressbook_name);
      if (this._source == null)
        {
          yield;
        }

      /* Sanity check then tidy up. */
      assert (this._source != null);
      source_registry.disconnect (signal_id);

      this._source_file = source_file;

      if (is_default)
        {
          this.set_as_default ();
        }
    }

  public async void commit_contacts_to_addressbook ()
    {
      GLib.SList<E.Contact> contacts = null;

      this._contacts.reverse ();

      foreach (var c in this._contacts)
        {
          E.Contact contact = new E.Contact ();

          this._set_contact_fields (contact, c);

          contacts.prepend (contact);
        }

      try
        {
          GLib.SList<string> uids;

          yield this._addressbook.add_contacts (contacts, E.BookOperationFlags.NONE, null, out uids);

          foreach (unowned string uid in uids)
            this._e_contacts += uid;
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Couldn't add contacts: %s\n",
              e.message);
        }
    }

  public void commit_contacts_to_addressbook_sync ()
    {
      var main_loop = new MainLoop ();
      this.commit_contacts_to_addressbook.begin ((s, r) =>
        {
          this.commit_contacts_to_addressbook.end (r);
          main_loop.quit ();
        });
      TestUtils.loop_run_with_timeout (main_loop);
    }

  private void _set_contact_fields (E.Contact contact,
                                    Gee.HashMap<string, Value?> c)
    {
      bool added_contact_name = false;
      E.ContactName contact_name = new E.ContactName ();
      string contact_field_name = "contact_name";
      int min_len = contact_field_name.length;

      foreach (var k in c.keys)
        {
          if (k.length > min_len && k.slice(0, min_len) == contact_field_name)
            {
              var v = c.get (k).get_string ();
              if (k.index_of ("family") >= 0)
                {
                  contact_name.family = v;
                }
              else if (k.index_of ("given") >= 0)
                {
                  contact_name.given = v;
                }
              else if (k.index_of ("additional") >= 0)
                {
                  contact_name.additional = v;
                }
              else if (k.index_of ("prefixes") >= 0)
                {
                  contact_name.prefixes = v;
                }
              else if (k.index_of ("suffixes") >= 0)
                {
                  contact_name.suffixes = v;
                }

              added_contact_name = true;
            }
          else if (k == "avatar")
            {
              var v = c.get (k).get_string ();
              uint8[] photo_content;
              var file = File.new_for_path (v);

              try
                {
                  file.load_contents (null, out photo_content, null);

                  var cp = new ContactPhoto ();
                  cp.type = ContactPhotoType.INLINED;
                  cp.set_inlined (photo_content);

                  contact.set (E.Contact.field_id ("photo"), cp);
                }
              catch (GLib.Error e)
                {
                  GLib.warning ("\n\nCan't load avatar %s: %s\n\n", v,
                      e.message);
                }
            }
          else if (k == "email_addresses")
            {
              var v = c.get (k).get_string ();
              var addresses = v.split (",");

              foreach (var addr in addresses)
                {
                  contact.set (E.Contact.field_id ("email"), addr);
                }
            }
          else if (k == "im_addresses")
            {
              var v = c.get (k).get_string ();
              var addresses = this._parse_im_addrs (v);
              foreach (var addr in addresses.keys)
                {
                  var proto = addresses.get (addr);
                  contact.set (E.Contact.field_id (proto), addr);
                }
            }
          else if (k == Edsf.Persona.address_fields[0])
            {
              var pa_fd = (PostalAddressFieldDetails) c.get (k).get_object ();
              var pa = (PostalAddress) pa_fd.value;
              var address = new E.ContactAddress ();
              address.po = pa.po_box;
              address.ext = pa.extension;
              address.street = pa.street;
              address.locality = pa.locality;
              address.region = pa.region;
              address.code = pa.postal_code;
              address.country = pa.country;
              address.address_format = pa.address_format;

              contact.set (E.Contact.field_id (k), address);
           }
          else
            {
              var field_id = E.Contact.field_id (k);
              var v = c.get (k).get_string ();

              if (field_id != 0)
                {
                  contact.set (field_id, v);
                }
              else
                {
                  var vcard = (E.VCard) contact;
                  var attr = new E.VCardAttribute (null, k);
                  vcard.append_attribute_with_value (attr, v);
                }
            }
        }
      if (added_contact_name)
        {
          contact.set (E.Contact.field_id ("name"), contact_name);
        }
    }

  public void tear_down ()
    {
      Environment.set_variable ("FOLKS_BACKEND_EDS_USE_ADDRESS_BOOKS",
                                "", true);

      try
        {
          if (this._source_file != null)
            {
              debug ("Deleting address book ‘%s’ source file ‘%s’.",
                  this._addressbook_name, this._source_file.get_path ());
              this._source_file.delete ();
            }
        }
      catch (GLib.Error e)
        {
          GLib.error ("Unable to remove address book ‘%s’ source file ‘%s’: %s",
              this._addressbook_name, this._source_file.get_path (), e.message);
        }
      finally
        {
          this._source_file = null;
          this._source = null;
          this._addressbook = null;
          this._source_registry = null;
        }
    }

  private Gee.HashMap<string, string> _parse_im_addrs (string addr_str)
    {
      Gee.HashMap<string, string> ret = new Gee.HashMap<string, string> ();
      string[] im_addrs = addr_str.split (",");

      foreach (var a in im_addrs)
        {
          string[] info = a.split ("#");
          string proto = info[0];
          string addr = info[1];

          ret.set ((owned) addr, (owned) proto);
        }

      return ret;
    }
}
