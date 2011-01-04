/*
 * Copyright (C) 2008 Nokia Corporation.
 * Copyright (C) 2008 Zeeshan Ali (Khattak) <zeeshanak@gnome.org>.
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
 * Authors: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *          Travis Reitter <travis.reitter@collabora.co.uk>
 *
 * This file was originally part of Rygel.
 */

using Gee;
using GLib;

/**
 * Responsible for backend loading.
 *
 * The BackendStore manages the set of available Folks backends. The
 * {@link BackendStore.load_backends} function loads all compatible and enabled
 * backends and the {@link BackendStore.backend_available} signal notifies when
 * these backends are ready.
 */
public class Folks.BackendStore : Object {
  [CCode (has_target = false)]
  private delegate void ModuleInitFunc (BackendStore store);
  [CCode (has_target = false)]
  private delegate void ModuleFinalizeFunc (BackendStore store);

  /* this contains all backends, regardless of enabled or prepared state */
  private HashMap<string,Backend> _backend_hash;
  private HashMap<string,Backend> _prepared_backends;
  private File config_file;
  private GLib.KeyFile backends_key_file;
  private HashMap<string,unowned Module> modules;
  private static weak BackendStore instance;
  private bool _is_prepared = false;

  /**
   * Emitted when a backend has been added to the BackendStore.
   *
   * This will not be emitted until after {@link BackendStore.load_backends}
   * has been called.
   *
   * {@link Backend}s referenced in this signal are also included in
   * {@link BackendStore.enabled_backends}.
   *
   * @param backend the new {@link Backend}
   */
  public signal void backend_available (Backend backend);

  /**
   * The list of backends visible to this store which have not been explicitly
   * disabled.
   *
   * This list will be empty before {@link BackendStore.load_backends} has been
   * called.
   *
   * The backends in this list have been prepared and are ready to use.
   *
   * @since 0.2.0
   */
  public GLib.List<Backend> enabled_backends
    {
      owned get
        {
          var backends = new GLib.List<Backend> ();
          foreach (var backend in this._prepared_backends.values)
            backends.prepend (backend);

          return backends;
        }

      private set {}
    }

  /**
   * Whether {@link BackendStore.prepare} has successfully completed for this
   * store.
   *
   * @since 0.3.0
   */
  public bool is_prepared
    {
      get { return this._is_prepared; }

      private set {}
    }

  /**
   * Create a new BackendStore.
   */
  public static BackendStore dup ()
    {
      if (instance == null)
        {
          /* use an intermediate variable to force a strong reference */
          var new_instance = new BackendStore ();
          instance = new_instance;

          return new_instance;
        }

      return instance;
    }

  private BackendStore ()
    {
      var debug = Debug.dup ();

      /* Treat this as a library init function */
      debug._set_flags (Environment.get_variable ("FOLKS_DEBUG"));

      this.modules = new HashMap<string,unowned Module> (str_hash, str_equal);
      this._backend_hash = new HashMap<string,Backend> (str_hash, str_equal);
      this._prepared_backends = new HashMap<string,Backend> (str_hash,
          str_equal);
    }

  ~BackendStore ()
    {
      /* Finalize all the loaded modules that have finalize functions */
      foreach (var module in this.modules.values)
        {
          void* func;
          if (module.symbol ("module_finalize", out func))
            {
              ModuleFinalizeFunc module_finalize = (ModuleFinalizeFunc) func;
              module_finalize (this);
            }
        }

      /* manually clear the singleton instance */
      instance = null;
    }

  /**
   * Prepare the BackendStore for use.
   *
   * This must only ever be called before {@link BackendStore.load_backends} is
   * called for the first time. If it isn't called explicitly,
   * {@link BackendStore.load_backends} will call it.
   *
   * @since 0.3.0
   */
  public async void prepare ()
    {
      /* (re-)load the list of disabled backends */
      yield this._load_disabled_backend_names ();

      if (this._is_prepared == true)
        return;
      this._is_prepared = true;

      this.notify_property ("is-prepared");
    }

  /**
   * Find, load, and prepare all backends which are not disabled.
   *
   * Backends will be searched for in the path given by the `FOLKS_BACKEND_PATH`
   * environment variable, if it's set. If it's not set, backends will be
   * searched for in a path set at compilation time.
   */
  public async void load_backends () throws GLib.Error
    {
      assert (Module.supported());

      yield this.prepare ();

      /* unload backends that have been disabled since they were loaded */
      foreach (var backend_existing in this._backend_hash.values)
        {
          yield this._backend_unload_if_needed (backend_existing);
        }

      var path = Environment.get_variable ("FOLKS_BACKEND_PATH");
      if (path == null)
        {
          path = BuildConf.BACKEND_DIR;

          debug ("Using built-in backend dir '%s' (override with " +
              "environment variable FOLKS_BACKEND_PATH)", path);
        }
      else
        {
          debug ("Using environment variable FOLKS_BACKEND_PATH = " +
              "'%s' to look for backends", path);
        }

      var modules = new HashMap<string, File?> ();
      var path_split = path.split (":");
      foreach (unowned string subpath in path_split)
        {
          var file = File.new_for_path (subpath);
          assert (file != null);

          bool is_file;
          bool is_dir;
          yield this._get_file_info (file, out is_file, out is_dir);
          if (is_file)
            {
              modules.set (subpath, file);
            }
          else if (is_dir)
            {
              var cur_modules = yield this._get_modules_from_dir (file);
              foreach (var entry in cur_modules.entries)
                modules.set (entry.key, entry.value);
            }
          else
            {
              critical ("FOLKS_BACKEND_PATH component '%s' is not a regular " +
                  "file or directory; ignoring...",
                  subpath);
              assert_not_reached ();
            }
        }

      /* this will load any new modules found in the backends dir and will
       * prepare and unprepare backends such that they match the state in the
       * backend store key file */
      foreach (var module in modules.values)
        this._load_module_from_file (module);

      /* this is populated indirectly from _load_module_from_file(), above */
      foreach (var backend in this._backend_hash.values)
        yield this._backend_load_if_needed (backend);
    }

  private async void _backend_load_if_needed (Backend backend)
    {
      if (this._backend_is_enabled (backend.name))
        {
          if (!this._prepared_backends.has_key (backend.name))
            {
              try
                {
                  yield backend.prepare ();

                  debug ("New backend '%s' prepared", backend.name);
                  this._prepared_backends.set (backend.name, backend);
                  this.backend_available (backend);
                }
              catch (GLib.Error e)
                {
                  /* Translators: the first parameter is a backend name, and the
                   * second is an error message. */
                  warning (_("Error preparing Backend '%s': %s"),
                      backend.name, e.message);
                }
            }
        }
    }

  private async bool _backend_unload_if_needed (Backend backend)
    {
      var unloaded = false;

      if (!this._backend_is_enabled (backend.name))
        {
          var backend_existing = this._backend_hash.get (backend.name);
          if (backend_existing != null)
            {
              try
                {
                  yield backend_existing.unprepare ();
                }
              catch (GLib.Error e)
                {
                  warning ("Error unpreparing Backend '%s': %s", backend.name,
                      e.message);
                }

              this._prepared_backends.unset (backend_existing.name);

              unloaded = true;
            }
        }

      return unloaded;
    }

  /**
   * Add a new {@link Backend} to the BackendStore.
   *
   * @param backend the {@link Backend} to add
   */
  public void add_backend (Backend backend)
    {
      /* Purge any other backend with the same name; re-add if enabled */
      var backend_existing = this._backend_hash.get (backend.name);
      if (backend_existing != null && backend_existing != backend)
        {
          backend_existing.unprepare ();
          this._prepared_backends.unset (backend_existing.name);
        }

      this._backend_hash.set (backend.name, backend);
    }

  private bool _backend_is_enabled (string name)
    {
      var enabled = true;
      try
        {
          enabled = this.backends_key_file.get_boolean (name, "enabled");
        }
      catch (KeyFileError e)
        {
          if (!(e is KeyFileError.GROUP_NOT_FOUND) &&
              !(e is KeyFileError.KEY_NOT_FOUND))
            {
              warning ("Couldn't check enabled state of backend '%s': %s\n" +
                  "Disabling backend.",
                  name, e.message);
              enabled = false;
            }
        }

      return enabled;
    }

  /**
   * Get a backend from the store by name.
   *
   * @param name the backend name to retrieve
   * @return the backend, or `null` if none could be found
   */
  public Backend? get_backend_by_name (string name)
    {
      return this._backend_hash.get (name);
    }

  /**
   * List the currently loaded backends.
   *
   * @return a list of the backends currently in the BackendStore
   */
  public Collection<Backend> list_backends ()
    {
      return this._backend_hash.values;
    }

  /**
   * Enable a backend.
   *
   * Mark a backend as enabled, such that the BackendStore will always attempt
   * to load it when {@link BackendStore.load_backends} is called. This will
   * not load the backend if it's not currently loaded.
   *
   * @param name the name of the backend to enable
   * @since 0.3.2
   */
  public async void enable_backend (string name)
    {
      this.backends_key_file.set_boolean (name, "enabled", true);
      yield this._save_key_file ();
    }

  /**
   * Disable a backend.
   *
   * Mark a backend as disabled, such that it won't be loaded even when the
   * client application is restarted. This will not remove the backend if it's
   * already loaded.
   *
   * @param name the name of the backend to disable
   * @since 0.3.2
   */
  public async void disable_backend (string name)
    {
      this.backends_key_file.set_boolean (name, "enabled", false);
      yield this._save_key_file ();
    }

  private async HashMap<string, File>? _get_modules_from_dir (File dir)
    {
      debug ("Searching for modules in folder '%s' ..", dir.get_path ());

      var attributes =
          FILE_ATTRIBUTE_STANDARD_NAME + "," +
          FILE_ATTRIBUTE_STANDARD_TYPE + "," +
          FILE_ATTRIBUTE_STANDARD_IS_SYMLINK + "," +
          FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE;

      GLib.List<FileInfo> infos;
      try
        {
          FileEnumerator enumerator =
            yield dir.enumerate_children_async (attributes,
                FileQueryInfoFlags.NONE, Priority.DEFAULT, null);

          infos = yield enumerator.next_files_async (int.MAX,
              Priority.DEFAULT, null);
        }
      catch (Error error)
        {
          /* Translators: the first parameter is a folder path and the second
           * is an error message. */
          critical (_("Error listing contents of folder '%s': %s"),
              dir.get_path (), error.message);

          return null;
        }

      var modules_final = new HashMap<string, File> (str_hash, str_equal);

      foreach (var info in infos)
        {
          var file = dir.get_child (info.get_name ());
          var file_type = info.get_file_type ();
          unowned string content_type = info.get_content_type ();
          /* don't load the library multiple times for its various symlink
           * aliases */
          var is_symlink = info.get_is_symlink ();

#if VALA_0_12
          string mime = ContentType.get_mime_type (content_type);
#else
          string mime = g_content_type_get_mime_type (content_type);
#endif

          if (file_type == FileType.DIRECTORY)
            {
              var modules = yield this._get_modules_from_dir (file);
              foreach (var entry in modules.entries)
                modules_final.set (entry.key, entry.value);
            }
          else if (mime == "application/x-sharedlib" && !is_symlink)
            {
              modules_final.set (file.get_path (), file);
            }
          else if (mime == null)
            {
              warning (
                  /* Translators: the parameter is a filename. */
                  _("The content type of '%s' could not be determined. Have you installed shared-mime-info?"),
                  file.get_path ());
            }
        }

      debug ("Finished searching for modules in folder '%s'",
          dir.get_path ());

      return modules_final;
    }

  private void _load_module_from_file (File file)
    {
      var file_path = file.get_path ();

      if (this.modules.has_key (file_path))
        return;

      Module module = Module.open (file_path, ModuleFlags.BIND_LOCAL);
      if (module == null)
        {
          /* Translators: the first parameter is a filename and the second is an
           * error message. */
          warning (_("Failed to load module from path '%s': %s"),
                    file_path, Module.error ());

          return;
        }

      void* function;

      /* this causes the module to call add_backend() for its backends (adding
       * them to the backend hash); any backends that already existed will be
       * removed if they've since been disabled */
      if (!module.symbol("module_init", out function))
        {
          /* Translators: the first parameter is a function name, the second is
           * a filename and the third is an error message. */
          warning (_("Failed to find entry point function '%s' in '%s': %s"),
                    "module_init",
                    file_path,
                    Module.error ());

          return;
        }

      ModuleInitFunc module_init = (ModuleInitFunc) function;
      assert (module_init != null);

      this.modules.set (file_path, module);

      /* We don't want our modules to ever unload */
      module.make_resident ();

      module_init (this);

      debug ("Loaded module source: '%s'", module.name ());
    }

  private async static void _get_file_info (File file,
      out bool is_file,
      out bool is_dir)
    {
      FileInfo file_info;
      is_file = false;
      is_dir = false;

      try
        {
          /* Query for the MIME type; if the file doesn't exist, we'll get an
           * appropriate error back, so this also checks for existence. */
          file_info = yield file.query_info_async (FILE_ATTRIBUTE_STANDARD_TYPE,
              FileQueryInfoFlags.NONE, Priority.DEFAULT, null);
        }
      catch (Error error)
        {
          if (error is IOError.NOT_FOUND)
            {
              /* Translators: the parameter is a filename. */
              critical (_("File or directory '%s' does not exist."),
                  file.get_path ());
            }
          else
            {
              /* Translators: the parameter is a filename. */
              critical (_("Failed to get content type for '%s'."),
                  file.get_path ());
            }

          return;
        }

      is_file = (file_info.get_file_type () == FileType.REGULAR);
      is_dir = (file_info.get_file_type () == FileType.DIRECTORY);
    }

  private async void _load_disabled_backend_names ()
    {
      File file;
      unowned string path = Environment.get_variable (
          "FOLKS_BACKEND_STORE_KEY_FILE_PATH");
      if (path == null)
        {
          file = File.new_for_path (Environment.get_user_data_dir ());
          file = file.get_child ("folks");
          file = file.get_child ("backends.ini");

          debug ("Using built-in backends key file '%s' (override with " +
              "environment variable FOLKS_BACKEND_STORE_KEY_FILE_PATH)",
              file.get_path ());
        }
      else
        {
          file = File.new_for_path (path);
          debug ("Using environment variable " +
              "FOLKS_BACKEND_STORE_KEY_FILE_PATH = '%s' to load the backends " +
              "key file.", path);
        }

      this.config_file = file;

      /* Load the disabled backends file */
      this.backends_key_file = new GLib.KeyFile ();
      try
        {
          string contents = null;
          size_t length = 0;

          yield file.load_contents_async (null, out contents, out length);
          if (length > 0)
            {
              this.backends_key_file.load_from_data (contents, length,
                  KeyFileFlags.KEEP_COMMENTS);
            }
        }
      catch (Error e1)
        {
          if (!(e1 is IOError.NOT_FOUND))
            {
              warning ("The backends key file '%s' could not be loaded: %s",
                  file.get_path (), e1.message);
              return;
            }
        }
    }

  private async void _save_key_file ()
    {
      var key_file_data = this.backends_key_file.to_data ();

      debug ("Saving backend key file '%s'.", this.config_file.get_path ());

      try
        {
          /* Note: We have to use key_file_data.size () here to get its length
           * in _bytes_ rather than _characters_. bgo#628930.
           * In Vala >= 0.11, string.size() has been deprecated in favour of
           * string.length (which now returns the byte length, whereas in
           * Vala <= 0.10, it returned the character length). FIXME: We need to
           * take this into account until we depend explicitly on
           * Vala >= 0.11. */
#if VALA_0_12
          yield this.config_file.replace_contents_async (key_file_data,
              key_file_data.length, null, false, FileCreateFlags.PRIVATE,
              null);
#else
          yield this.config_file.replace_contents_async (key_file_data,
              key_file_data.size (), null, false, FileCreateFlags.PRIVATE,
              null);
#endif
        }
      catch (Error e)
        {
          warning ("Could not write updated backend key file '%s': %s",
              this.config_file.get_path (), e.message);
        }
    }
}
