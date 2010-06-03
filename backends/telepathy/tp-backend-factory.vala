/*
 * Copyright (C) 2009 Zeeshan Ali (Khattak) <zeeshanak@gnome.org>.
 * Copyright (C) 2009 Nokia Corporation.
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

using Folks;

private TpBackendFactory backend_factory = null;

public void module_init (BackendStore backend_store)
{
  if (backend_factory == null)
    backend_factory = new TpBackendFactory (backend_store);
}

public class TpBackendFactory : Object
{
  BackendStore backend_store;

  public TpBackendFactory (BackendStore backend_store)
    {
      this.backend_store = backend_store;

      try
        {
          this.backend_store.add_backend (new TpBackend ());
        }
      catch (GLib.Error e)
        {
          warning ("Failed to add Telepathy backend to libfolks: %s",
              e.message);
        }
    }
}
