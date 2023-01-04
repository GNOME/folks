/*
 * Copyright 2011,2023 Collabora Ltd.
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
 *       Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *       Corentin Noël <corentin.noel@collabora.com>
 */

using GLib;
using Gee;
using Posix;

namespace Folks.Internal
{
  public static bool equal_sets<G> (Set<G> a, Set<G> b)
    {
      if (a.size != b.size)
        return false;

      foreach (var a_elem in a)
        {
          if (!b.contains (a_elem))
            return false;
        }

      return true;
    }

  /**
   * Emit a profiling point.
   *
   * This emits a profiling point with the given message (printf-style), which
   * can be picked up by profiling tools and timing information extracted.
   *
   * @param format printf-style message format
   * @param ... message arguments
   */
  [PrintfFormat]
  public inline void profiling_point (string format, ...)
    {
#if ENABLE_PROFILING
      var args = va_list ();
      Sysprof.Collector.log (0, "folks", format.vprintf(args));
#endif
    }

  [Compact]
  public class ProfileBlock
    {
#if ENABLE_PROFILING
      internal string name;
      internal int64 start;

      internal ProfileBlock (owned string name) {
        this.name = (owned) name;
        this.start = Sysprof.CAPTURE_CURRENT_TIME;
      }
#endif
    }

  /**
   * Start a profiling block.
   *
   * This emits a profiling start point with the given message (printf-style),
   * which can be picked up by profiling tools and timing information extracted.
   *
   * This is typically used in a pair with {@link Internal.profiling_end} to
   * delimit blocks of processing which need timing.
   *
   * @param format printf-style message format
   * @param ... message arguments
   */
  public inline ProfileBlock? profiling_start (string format, ...)
    {
#if ENABLE_PROFILING
      var args = va_list ();
      return new ProfileBlock (format.vprintf (args));
#else
      return null;
#endif
    }

  /**
   * End a profiling block.
   *
   * This emits a profiling end point with the given message (printf-style),
   * which can be picked up by profiling tools and timing information extracted.
   *
   * This is typically used in a pair with {@link Internal.profiling_start} to
   * delimit blocks of processing which need timing.
   *
   * @param block the ProfileBlock given by profiling_start
   */
  public inline void profiling_end (owned ProfileBlock? block)
    {
#if ENABLE_PROFILING
        Sysprof.Collector.mark (block.start, Sysprof.CAPTURE_CURRENT_TIME - block.start, "folks", block.name);
#endif
    }
}
