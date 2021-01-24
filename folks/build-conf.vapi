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

[CCode (cheader_filename = "config.h")]
public class Folks.BuildConf
{
  [CCode (cname = "BACKEND_DIR")]
  public const string BACKEND_DIR;

  [CCode (cname = "PACKAGE_NAME")]
  public const string PACKAGE_NAME;

  [CCode (cname = "PACKAGE_VERSION")]
  public const string PACKAGE_VERSION;

  [CCode (cname = "PACKAGE_STRING")]
  public const string PACKAGE_STRING;

  [CCode (cname = "PACKAGE_DATADIR")]
  public const string PACKAGE_DATADIR;

  [CCode (cname = "GETTEXT_PACKAGE")]
  public const string GETTEXT_PACKAGE;

  [CCode (cname = "LOCALE_DIR")]
  public const string LOCALE_DIR;

  [CCode (cname = "HAVE_EDS")]
  public static bool HAVE_EDS;

  [CCode (cname = "EDS_SOURCES_SERVICE_NAME")]
  public const string EDS_SOURCES_SERVICE_NAME;

  [CCode (cname = "EDS_ADDRESS_BOOK_SERVICE_NAME")]
  public const string EDS_ADDRESS_BOOK_SERVICE_NAME;

  [CCode (cname = "HAVE_OFONO")]
  public static bool HAVE_OFONO;

  [CCode (cname = "HAVE_BLUEZ")]
  public static bool HAVE_BLUEZ;

  [CCode (cname = "HAVE_TELEPATHY")]
  public static bool HAVE_TELEPATHY;

  [CCode (cname = "ABS_TOP_BUILDDIR")]
  public const string ABS_TOP_BUILDDIR;

  [CCode (cname = "ABS_TOP_SRCDIR")]
  public const string ABS_TOP_SRCDIR;

  [CCode (cname = "PKGLIBEXECDIR")]
  public const string PKGLIBEXECDIR;

  [CCode (cname = "INSTALLED_TESTS_DIR")]
  public const string INSTALLED_TESTS_DIR;

  [CCode (cname = "INSTALLED_TESTS_META_DIR")]
  public const string INSTALLED_TESTS_META_DIR;
}
