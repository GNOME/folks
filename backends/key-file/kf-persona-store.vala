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
 *
 * @since 0.1.13
 */
public class Folks.Backends.Kf.PersonaStore : Folks.PersonaStore
{
  private HashTable<string, Persona> _personas;
  private File _file;
  private GLib.KeyFile _key_file;
  private unowned Cancellable _save_key_file_cancellable = null;
  private bool _is_prepared = false;

  /**
   * {@inheritDoc}
   */
  public override string type_id { get { return BACKEND_NAME; } }

  /**
   * Whether this PersonaStore can add {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_add_personas}.
   *
   * @since 0.3.1
   */
  public override MaybeBool can_add_personas
    {
      get { return MaybeBool.TRUE; }
    }

  /**
   * Whether this PersonaStore can set the alias of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_alias_personas}.
   *
   * @since 0.3.1
   */
  public override MaybeBool can_alias_personas
    {
      get { return MaybeBool.TRUE; }
    }

  /**
   * Whether this PersonaStore can set the groups of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_group_personas}.
   *
   * @since 0.3.1
   */
  public override MaybeBool can_group_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore can remove {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_remove_personas}.
   *
   * @since 0.3.1
   */
  public override MaybeBool can_remove_personas
    {
      get { return MaybeBool.TRUE; }
    }

  /**
   * Whether this PersonaStore has been prepared.
   *
   * See {@link Folks.PersonaStore.is_prepared}.
   *
   * @since 0.3.0
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

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
      var id = key_file.get_basename ();

      Object (id: id,
              display_name: id);

      this.trust_level = PersonaStoreTrust.FULL;
      this._file = key_file;
      this._personas = new HashTable<string, Persona> (str_hash, str_equal);
    }

  /**
   * {@inheritDoc}
   */
  public override async void prepare ()
    {
      lock (this._is_prepared)
        {
          if (!this._is_prepared)
            {
              var filename = this._file.get_path ();
              this._key_file = new GLib.KeyFile ();

              /* Load or create the file */
              while (true)
                {
                  /* Load the file; if this fails due to the file not existing
                   * or having been deleted in the meantime, we can continue
                   * below and try to create it instead. */
                  try
                    {
                      string contents = null;
                      size_t length = 0;

                      yield this._file.load_contents_async (null, out contents,
                          out length);
                      if (length > 0)
                        {
                          this._key_file.load_from_data (contents, length,
                              KeyFileFlags.KEEP_COMMENTS);
                        }
                      break;
                    }
                  catch (Error e1)
                    {
                      if (!(e1 is IOError.NOT_FOUND))
                        {
                          warning (
                              /* Translators: the first parameter is a filename,
                               * and the second is an error message. */
                              _("The relationship key file '%s' could not be loaded: %s"),
                              filename, e1.message);
                          this.removed ();
                          return;
                        }
                    }

                  /* Ensure the parent directory tree exists for the new file */
                  File parent_dir = this._file.get_parent ();

                  try
                    {
                      /* Recursively create the directory */
                      parent_dir.make_directory_with_parents ();
                    }
                  catch (Error e3)
                    {
                      if (!(e3 is IOError.EXISTS))
                        {
                          warning (
                              /* Translators: the first parameter is a path, and
                               * the second is an error message. */
                              _("The relationship key file directory '%s' could not be created: %s"),
                              parent_dir.get_path (), e3.message);
                          this.removed ();
                          return;
                        }
                    }

                  /* Create a new file; if this fails due to the file having
                   * been created in the meantime, we can loop back round and
                   * try and load it. */
                  try
                    {
                      /* Create the file */
                      FileOutputStream stream = yield this._file.create_async (
                          FileCreateFlags.PRIVATE, Priority.DEFAULT);
                      yield stream.close_async (Priority.DEFAULT);
                    }
                  catch (Error e2)
                    {
                      if (!(e2 is IOError.EXISTS))
                        {
                          warning (
                              /* Translators: the first parameter is a filename,
                               * and the second is an error message. */
                              _("The relationship key file '%s' could not be created: %s"),
                              filename, e2.message);
                          this.removed ();
                          return;
                        }
                    }
                }

              /* We've loaded or created a key file by now, so cycle through the
               * groups: each group is a persona which we have to create and
               * emit */
              var groups = this._key_file.get_groups ();
              foreach (var persona_id in groups)
                {
                  Persona persona = new Kf.Persona (this._key_file, persona_id,
                      this);
                  this._personas.insert (persona.iid, persona);
                }

              if (this._personas.size () > 0)
                {
                  /* FIXME: GroupDetails.ChangeReason is not the right enum to
                   * use here */
                  this.personas_changed (this._personas.get_values (), null,
                      null, null, GroupDetails.ChangeReason.NONE);
                }

              this._is_prepared = true;
              this.notify_property ("is-prepared");
            }
        }
    }

  /**
   * {@inheritDoc}
   */
  public override async void flush ()
    {
      /* If there are any ongoing file operations, wait for them to finish
       * before returning. We have to iterate the main context manually to
       * achieve this, as all the code in this file is run in the main loop (in
       * the main thread). We would cause a deadlock if we used anything as
       * fancy/useful as a GCond. */
      MainContext context = MainContext.default ();
      while (this._save_key_file_cancellable != null)
        context.iteration (true);
    }

  /**
   * {@inheritDoc}
   */
  public override async void remove_persona (Folks.Persona persona)
    {
      debug ("Removing Persona '%s' (IID '%s', group '%s')", persona.uid,
          persona.iid, persona.display_id);

      try
        {
          this._key_file.remove_group (persona.display_id);
          yield this.save_key_file ();

          /* Signal the removal of the Persona */
          GLib.List<Folks.Persona> personas = new GLib.List<Folks.Persona> ();
          personas.prepend (persona);
          this.personas_changed (null, personas, null, null, 0);
        }
      catch (KeyFileError e)
        {
          /* Ignore the error, since it's only about a missing group */
        }
    }

  /**
   * Add a new {@link Persona} to the PersonaStore.
   *
   * Accepted keys for `details` are:
   * - PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES)
   *
   * See {@link Folks.PersonaStore.add_persona_from_details}.
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      unowned Value val =
        details.lookup (this.detail_key (PersonaDetail.IM_ADDRESSES));
      unowned HashTable<string, LinkedHashSet<string>> im_addresses =
          (HashTable<string, LinkedHashSet<string>>) val.get_boxed ();

      if (im_addresses == null || im_addresses.size () == 0)
        {
          throw new PersonaStoreError.INVALID_ARGUMENT (
              /* Translators: the first two parameters are identifiers for the
               * persona store. The third is a pointer address. Do not translate
               * "im-addresses", as it's an object property name. */
              _("Persona store (%s, %s) requires the following details:\n    im-addresses (provided: '%p')"),
              this.type_id, this.id, im_addresses);
        }

      debug ("Adding Persona from details.");

      /* Generate a new random number for the persona's ID, so as to try and
       * ensure that IDs don't get recycled; if they did, anti-links which were
       * made against a key-file persona which used an ID which has been
       * re-used would be applied to the wrong persona (the new one, instead of
       * the old one, which could've been completely different). */
      string persona_id = null;
      do
        {
          persona_id = Random.next_int ().to_string ();
        }
      while (this._key_file.has_group (persona_id) == true);

      /* Create a new persona and set its im-addresses property to update the
       * key file */
      Persona persona = new Kf.Persona (this._key_file, persona_id, this);
      this._personas.insert (persona.iid, persona);
      persona.im_addresses = im_addresses;

      /* FIXME: GroupDetails.ChangeReason is not the right enum to use here */
      GLib.List<Persona> personas = new GLib.List<Persona> ();
      personas.prepend (persona);
      this.personas_changed (personas, null, null, null,
          GroupDetails.ChangeReason.NONE);

      return persona;
    }

  internal async void save_key_file ()
    {
      var key_file_data = this._key_file.to_data ();
      var cancellable = new Cancellable ();

      debug ("Saving key file '%s'.", this._file.get_path ());

      /* There's no point in having two competing file write operations.
       * We can ensure that only one is running by just checking if a
       * cancellable is set. This is thread safe because the code in this file
       * is all run in the main thread (inside the main loop), so only we touch
       * this._save_key_file_cancellable (albeit in many weird and wonderful
       * orders due to idle handler queuing). */
      if (this._save_key_file_cancellable != null)
        this._save_key_file_cancellable.cancel ();
      this._save_key_file_cancellable = cancellable;

      try
        {
          /* Note: We have to use key_file_data.size () here to get its length
           * in _bytes_ rather than _characters_. bgo#628930.
           * In Vala >= 0.11, string.size() has been deprecated in favour of
           * string.length (which now returns the byte length, whereas in
           * Vala <= 0.10, it returned the character length). FIXME: We need to
           * take this into account until we depend explicitly on
           * Vala >= 0.11. */
          yield this._file.replace_contents_async (key_file_data,
              key_file_data.length, null, false, FileCreateFlags.PRIVATE,
              cancellable);
        }
      catch (Error e)
        {
          if (!(e is IOError.CANCELLED))
            {
              /* Translators: the first parameter is a filename, the second is
               * an error message. */
              warning (_("Could not write updated key file '%s': %s"),
                  this._file.get_path (), e.message);
            }
        }

      if (this._save_key_file_cancellable == cancellable)
        this._save_key_file_cancellable = null;
    }
}
