/*
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

public class BuildConf
{
  [CCode (cname = "DATA_DIR")]
  public static const string DATA_DIR;

  [CCode (cname = "BACKEND_DIR")]
  public static const string BACKEND_DIR;

  [CCode (cname = "PACKAGE_NAME")]
  public static const string PACKAGE_NAME;

  [CCode (cname = "PACKAGE_VERSION")]
  public static const string PACKAGE_VERSION;

  [CCode (cname = "PACKAGE_STRING")]
  public static const string PACKAGE_STRING;
}
