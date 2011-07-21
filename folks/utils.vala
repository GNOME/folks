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
 * Authors:
 *       Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *       Travis Reitter <travis.reitter@collabora.co.uk>
 */

using Gee;

public class Folks.Utils : Object
{
  internal static bool _str_equal_safe (string a, string b)
    {
      return (a != "" && b != "" && a.down () == b.down ());
    }

  public static bool multi_map_str_str_equal (
      MultiMap<string, string> a,
      MultiMap<string, string> b)
    {
      if (a == b)
        return true;

      if (a.size == b.size)
        {
          foreach (var key in a.get_keys ())
            {
              if (b.contains (key))
                {
                  var a_values = a.get (key);
                  var b_values = b.get (key);
                  if (a_values.size != b_values.size)
                    return false;

                  foreach (var a_value in a_values)
                    {
                      if (!b_values.contains (a_value))
                        return false;
                    }
                }
              else
                {
                  return false;
                }
            }
        }
      else
        {
          return false;
        }

      return true;
    }
}