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
 *          Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *
 * This file was originally part of Rygel.
 */

using Folks;
using Folks.Backends.Tr;

private BackendFactory _backend_factory = null;

/**
 * The tracker backend module entry point.
 */
public void module_init (BackendStore backend_store)
{
  _backend_factory = new BackendFactory (backend_store);
}

/**
 * The tracker backend module exit point.
 */
public void module_finalize (BackendStore backend_store)
{
  _backend_factory = null;
}

/**
 * A backend factory to create a single {@link Backend}.
 */
public class Folks.Backends.Tr.BackendFactory : Object
{
  /**
   * {@inheritDoc}
   */
  public BackendFactory (BackendStore backend_store)
    {
      backend_store.add_backend (new Backend ());
    }
}
