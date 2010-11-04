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

  private HashMap<string,Backend> backend_hash;
  private HashMap<string,Backend> _prepared_backends;
  private File config_file;
  private GLib.KeyFile backends_key_file;
  private GLib.List<ModuleFinalizeFunc> finalize_funcs = null;
  private static weak BackendStore instance;
  private static bool _backends_loaded = false;
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
          foreach (var entry in this._prepared_backends)
            backends.prepend (entry.value);

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
      /* Treat this as a library init function */
      Debug.set_flags (Environment.get_variable ("FOLKS_DEBUG"));

      this.backend_hash = new HashMap<string,Backend> (str_hash, str_equal);
      this._prepared_backends = new HashMap<string,Backend> (str_hash,
          str_equal);
    }

  ~BackendStore ()
    {
      /* Finalize all the loaded modules */
      foreach (ModuleFinalizeFunc func in this.finalize_funcs)
        func (this);

      /* reset status of backends */
      lock (this._backends_loaded)
        this._backends_loaded = false;

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
      if (this._is_prepared == true)
        return;
      this._is_prepared = true;

      /* Load the list of disabled backends */
      yield this.load_disabled_backend_names ();

      this.notify_property ("is-prepared");
    }

  /**
   * Find, load, and prepare all backends which are not disabled.
   *
   * Backends will be searched for in the path given by the `FOLKS_BACKEND_DIR`
   * environment variable, if it's set. If it's not set, backends will be
   * searched for in a path set at compilation time.
   */
  public async void load_backends () throws GLib.Error
    {
      lock (this._backends_loaded)
        {
          if (!this._backends_loaded)
            {
              assert (Module.supported());

              if (this._is_prepared == false)
                yield this.prepare ();

              var path = Environment.get_variable ("FOLKS_BACKEND_DIR");
              if (path == null)
                {
                  path = BuildConf.BACKEND_DIR;

                  debug ("Using built-in backend dir '%s' (override with " +
                      "environment variable FOLKS_BACKEND_DIR)", path);
                }
              else
                {
                  debug ("Using environment variable FOLKS_BACKEND_DIR = " +
                      "'%s' to look for backends", path);
                }

              File dir = File.new_for_path (path);
              assert (dir != null && yield is_dir (dir));

              var modules = yield this.get_modules_from_dir (dir);
              foreach (var entry in modules)
                {
                  var module = (File) entry.value;
                  this.load_module_from_file (module);
                }

              /* this is populated indirectly from load_module_from_file(),
               * above */
              foreach (var backend in this.backend_hash.values)
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
                      warning ("Error preparing Backend '%s': %s", backend.name,
                          e.message);
                    }
                }

              this._backends_loaded = true;
            }
        }
    }

  /**
   * Add a new {@link Backend} to the BackendStore.
   *
   * @param backend the {@link Backend} to add
   */
  public void add_backend (Backend backend)
    {
      /* Check the backend isn't disabled */
      bool enabled = true;
      try
        {
          enabled = this.backends_key_file.get_boolean (backend.name,
              "enabled");
        }
      catch (KeyFileError e)
        {
          if (!(e is KeyFileError.GROUP_NOT_FOUND) &&
              !(e is KeyFileError.KEY_NOT_FOUND))
            {
              warning ("Couldn't check enabled state of backend '%s': %s\n" +
                  "Disabling backend.",
                  backend.name, e.message);
              enabled = false;
            }
        }

      if (enabled == true)
        this.backend_hash.set (backend.name, backend);
    }

  /**
   * Get a backend from the store by name.
   *
   * @param name the backend name to retrieve
   * @return the backend, or `null` if none could be found
   */
  public Backend? get_backend_by_name (string name)
    {
      return this.backend_hash.get (name);
    }

  /**
   * List the currently loaded backends.
   *
   * @return a list of the backends currently in the BackendStore
   */
  public Collection<Backend> list_backends ()
    {
      return this.backend_hash.values;
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
      yield this.save_key_file ();
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
      yield this.save_key_file ();
    }

  private async HashMap<string, File>? get_modules_from_dir (File dir)
    {
      debug ("Searching for modules in folder '%s' ..", dir.get_path ());

      string attributes = FILE_ATTRIBUTE_STANDARD_NAME + "," +
                          FILE_ATTRIBUTE_STANDARD_TYPE + "," +
                          FILE_ATTRIBUTE_STANDARD_IS_SYMLINK + "," +
                          FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE;

      GLib.List<FileInfo> infos;
      FileEnumerator enumerator;

      try
        {
          enumerator = yield dir.enumerate_children_async (attributes,
              FileQueryInfoFlags.NONE, Priority.DEFAULT, null);

          infos = yield enumerator.next_files_async (int.MAX,
              Priority.DEFAULT, null);
        }
      catch (Error error)
        {
          critical ("Error listing contents of folder '%s': %s",
              dir.get_path (), error.message);

          return null;
        }

      var modules_final = new HashMap<string, File> (str_hash, str_equal);

      foreach (var info in infos)
        {
          File file = dir.get_child (info.get_name ());
          FileType file_type = info.get_file_type ();
          unowned string content_type = info.get_content_type ();
          /* don't load the library multiple times for its various symlink
           * aliases */
          var is_symlink = info.get_is_symlink ();

          string mime = g_content_type_get_mime_type (content_type);

          if (file_type == FileType.DIRECTORY)
            {
              var modules = yield this.get_modules_from_dir (file);
              foreach (var entry in modules)
                modules_final.set (entry.key, entry.value);
            }
          else if (mime == "application/x-sharedlib" && !is_symlink)
            {
              modules_final.set (file.get_path (), file);
            }
          else if (mime == null)
            {
              warning ("MIME type could not be determined for file '%s'. " +
                  "Have you installed shared-mime-info?", file.get_path ());
            }
        }

      debug ("Finished searching for modules in folder '%s'",
          dir.get_path ());

      return modules_final;
    }

  private void load_module_from_file (File file)
    {
      string file_path = file.get_path ();

      Module module = Module.open (file_path, ModuleFlags.BIND_LOCAL);
      if (module == null)
        {
          warning ("Failed to load module from path '%s' : %s",
                    file_path, Module.error ());

          return;
        }

      void* function;

      /* this causes the module to call add_backend() for its backends (adding
       * them to the backend hash) */
      if (!module.symbol("module_init", out function))
        {
          warning ("Failed to find entry point function '%s' in '%s': %s",
                    "module_init",
                    file_path,
                    Module.error ());

          return;
        }

      ModuleInitFunc module_init = (ModuleInitFunc) function;
      assert (module_init != null);

      /* It's optional for modules to have a finalize function */
      if (module.symbol ("module_finalize", out function))
        {
          ModuleFinalizeFunc module_finalize = (ModuleFinalizeFunc) function;
          this.finalize_funcs.prepend (module_finalize);
        }

      /* We don't want our modules to ever unload */
      module.make_resident ();

      module_init (this);

      debug ("Loaded module source: '%s'", module.name ());
    }

  private async static bool is_dir (File file)
    {
      FileInfo file_info;

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
            critical ("File or directory '%s' does not exist",
                      file.get_path ());
          else
            critical ("Failed to get content type for '%s'", file.get_path ());

          return false;
        }

      return file_info.get_file_type () == FileType.DIRECTORY;
    }

  private async void load_disabled_backend_names ()
    {
      File file;
      string path =
          Environment.get_variable ("FOLKS_BACKEND_STORE_KEY_FILE_PATH");
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

  private async void save_key_file ()
    {
      string key_file_data = this.backends_key_file.to_data ();

      debug ("Saving backend key file '%s'.", this.config_file.get_path ());

      try
        {
          /* Note: We have to use key_file_data.size () here to get its length
           * in _bytes_ rather than _characters_. bgo#628930 */
          yield this.config_file.replace_contents_async (key_file_data,
              key_file_data.size (), null, false, FileCreateFlags.PRIVATE,
              null);
        }
      catch (Error e)
        {
          warning ("Could not write updated backend key file '%s': %s",
              this.config_file.get_path (), e.message);
        }
    }
}
