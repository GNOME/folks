/*
 * Copyright (C) 2010 Collabora Ltd.
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
 * Authors:
 *       Travis Reitter <travis.reitter@collabora.co.uk>
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;
using Folks;
using Folks.Backends.Kf;

/**
 * A persona store which is associated with a single simple key file. It will
 * create a {@link Persona} for each of the groups in the key file.
 */
public class Folks.Backends.Kf.PersonaStore : Folks.PersonaStore
{
  private HashTable<string, Persona> _personas;
  private File file;
  private GLib.KeyFile key_file;
  private uint first_unused_id = 0;

  /**
   * {@inheritDoc}
   */
  public override string type_id { get; private set; }

  /**
   * {@inheritDoc}
   */
  public override string display_name { get; private set; }

  /**
   * {@inheritDoc}
   */
  public override string id { get; private set; }

  /**
   * {@inheritDoc}
   */
  public override HashTable<string, Persona> personas
    {
      get { return this._personas; }
    }

  /**
   * Create a new PersonaStore.
   *
   * Create a new persona store to expose the {@link Persona}s provided by the
   * different groups in the key file given by `key_file`.
   */
  public PersonaStore (File key_file)
    {
      this.type_id = "key-file";
      this.id = key_file.get_basename ();
      this.display_name = this.id; /* the user should _never_ see this */
      this.trust_level = PersonaStoreTrust.FULL;
      this.file = key_file;
      this._personas = new HashTable<string, Persona> (str_hash, str_equal);
    }

  public override async void prepare ()
    {
      string filename = this.file.get_path ();
      this.key_file = new GLib.KeyFile ();

      /* Load or create the file */
      while (true)
        {
          /* Load the file; if this fails due to the file not existing or having
           * been deleted in the meantime, we can continue below and try to
           * create it instead. */
          try
            {
              string contents = null;
              size_t length = 0;

              yield this.file.load_contents_async (null, out contents,
                  out length);
              if (length > 0)
                {
                  this.key_file.load_from_data (contents, length,
                      KeyFileFlags.KEEP_COMMENTS);
                }
              break;
            }
          catch (Error e1)
            {
              if (!(e1 is IOError.NOT_FOUND))
                {
                  warning ("The relationship key file '%s' could not be " +
                      "loaded: %s", filename, e1.message);
                  this.removed ();
                  return;
                }
            }

          /* Create a new file; if this fails due to the file having been
           * created in the meantime, we can loop back round and try and load
           * it. */
          try
            {
              /* Recursively create the directory */
              File parent_dir = this.file.get_parent ();
              parent_dir.make_directory_with_parents ();

              /* Create the file */
              FileOutputStream stream = yield this.file.create_async (
                  FileCreateFlags.PRIVATE, Priority.DEFAULT);
              yield stream.close_async (Priority.DEFAULT);
            }
          catch (Error e2)
            {
              if (!(e2 is IOError.EXISTS))
                {
                  warning ("The relationship key file '%s' could not be " +
                      "created: %s", filename, e2.message);
                  this.removed ();
                  return;
                }
            }
        }

      /* We've loaded or created a key file by now, so cycle through the groups:
       * each group is a persona which we have to create and emit */
      string[] groups = this.key_file.get_groups ();
      foreach (string persona_uid in groups)
        {
          if (persona_uid.to_int () == this.first_unused_id)
            this.first_unused_id++;

          Persona persona = new Kf.Persona (this.key_file, persona_uid, this);
          this._personas.insert (persona.iid, persona);
        }

      if (this._personas.size () > 0)
        {
          /* FIXME: Groups.ChangeReason is not the right enum to use here */
          this.personas_changed (this._personas.get_values (), null, null, null,
              Groups.ChangeReason.NONE);
        }
    }

  /**
   * {@inheritDoc}
   */
  public override async void remove_persona (Folks.Persona persona)
    {
      try
        {
          this.key_file.remove_group (persona.uid);
          yield this.save_key_file ();
        }
      catch (KeyFileError e)
        {
          /* Ignore the error, since it's only about a missing group */
        }
    }

  /**
   * {@inheritDoc}
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      Value val = details.lookup ("im-address");
      unowned string im_address = val.get_string ();
      val = details.lookup ("protocol");
      unowned string protocol = val.get_string ();

      if (im_address == null || protocol == null)
        {
          throw new PersonaStoreError.INVALID_ARGUMENT (
              "persona store (%s, %s) requires the following details:\n" +
              "    im-address (provided: '%s')\n",
              "    protocol (provided: '%s')\n",
              this.type_id, this.id, im_address, protocol);
        }

      string persona_id = this.first_unused_id.to_string ();
      this.first_unused_id++;

      /* Insert the new IM details into the key file and create a Persona from
       * them */
      string[] im_addresses = new string[1];
      im_addresses[0] = im_address;
      this.key_file.set_string_list (persona_id, protocol, im_addresses);
      yield this.save_key_file ();

      Persona persona = new Kf.Persona (this.key_file, persona_id, this);
      this._personas.insert (persona.iid, persona);

      /* FIXME: Groups.ChangeReason is not the right enum to use here */
      GLib.List<Persona> personas = new GLib.List<Persona> ();
      personas.prepend (persona);
      this.personas_changed (personas, null, null, null,
          Groups.ChangeReason.NONE);

      return persona;
    }

  internal async void save_key_file ()
    {
      string key_file_data = this.key_file.to_data ();

      try
        {
          yield this.file.replace_contents_async (key_file_data,
              key_file_data.length, null, false, FileCreateFlags.PRIVATE);
        }
      catch (Error e)
        {
          warning ("Could not write updated key file '%s': %s",
              this.file.get_path (), e.message);
        }
    }
}
