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

using BuildConf;
using Gee;
using GLib;

/**
 * Responsible for backend loading. Probes for shared library files in a
 * specific directory, looking for (and calling) a specific function (by name,
 * signature).
 */
public class Folks.BackendStore : Object {
  private delegate void ModuleInitFunc (BackendStore store);

  private HashMap<string,Backend> backend_hash;

  public signal void backend_available (Backend backend);

  public BackendStore ()
    {
      this.backend_hash = new HashMap<string,Backend> (str_hash, str_equal);
    }

  public void load_backends () {
      assert (Module.supported());

      var path = Environment.get_variable ("FOLKS_BACKEND_DIR");
      if (path == null)
        {
          path = BuildConf.BACKEND_DIR;

          debug ("Using built-in backend dir '%s' (override with environment "
              + "variable FOLKS_BACKEND_DIR)", path);
        }
      else
        {
          debug ("Using environment variable FOLKS_BACKEND_DIR = '%s' to look "
              + "for backends", path);
        }

      File dir = File.new_for_path (path);
      assert (dir != null && is_dir (dir));

      this.load_modules_from_dir.begin (dir);
  }

  public void add_backend (Backend backend)
    {
      message ("New backend '%s' available", backend.name);
      this.backend_hash.set (backend.name, backend);
      this.backend_available (backend);
    }

  public Backend? get_backend_by_name (string name)
    {
      return this.backend_hash.get (name);
    }

  public Collection<Backend> list_backends ()
    {
      return this.backend_hash.values;
    }

  private async void load_modules_from_dir (File dir)
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

          return;
        }

      foreach (var info in infos)
        {
          string file_name = info.get_name ();
          string file_path = Path.build_filename (dir.get_path (), file_name);

          File file = File.new_for_path (file_path);
          FileType file_type = info.get_file_type ();
          string content_type = info.get_content_type ();
          /* don't load the library multiple times for its various symlink
           * aliases */
          var is_symlink = info.get_is_symlink ();

          weak string mime = g_content_type_get_mime_type (content_type);

          if (file_type == FileType.DIRECTORY)
              this.load_modules_from_dir.begin (file);
          else if (mime == "application/x-sharedlib" && !is_symlink)
              this.load_module_from_file (file_path);
        }

      debug ("Finished searching for modules in folder '%s'",
          dir.get_path ());
    }

  private void load_module_from_file (string file_path)
    {
      Module module = Module.open (file_path, ModuleFlags.BIND_LOCAL);
      if (module == null)
        {
          warning ("Failed to load module from path '%s' : %s",
                    file_path, Module.error ());

          return;
        }

      void* function;

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

      /* We don't want our modules to ever unload */
      module.make_resident ();

      module_init (this);

      debug ("Loaded module source: '%s'", module.name ());
    }

  private static bool is_dir (File file)
    {
      FileInfo file_info;

      if (!file.query_exists (null))
        {
          critical ("File or directory '%s' does not exist", file.get_path ());
          return false;
        }

      try
        {
          file_info = file.query_info (FILE_ATTRIBUTE_STANDARD_TYPE,
              FileQueryInfoFlags.NONE, null);
        }
      catch (Error error)
        {
          critical ("Failed to get content type for '%s'",
              file.get_path ());

          return false;
        }

      return file_info.get_file_type () == FileType.DIRECTORY;
    }
}
