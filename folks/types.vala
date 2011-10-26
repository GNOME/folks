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
 */

using GLib;

/**
 * New general types required by Folks.
 *
 * @since 0.3.1
 */
namespace Folks
{
  /**
   * A 'boolean' type that has a distinct 'unset' state.
   *
   * @since 0.3.1
   */
  public enum MaybeBool
    {
      /**
       * This value is explicitly unset.
       */
      UNSET = 0,
      /**
       * False (this value was set from its default of UNSET).
       */
      FALSE = 1,
      /**
       * True (this value was set from its default of UNSET).
       */
      TRUE = 2,
    }
}
