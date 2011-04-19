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
 *       Alban Crequy <alban.crequy@collabora.co.uk>
 */

using Gee;

/**
 * web service addresses exposed by an object implementing
 * {@link PresenceDetails}.
 *
 * @since 0.5.0
 */
public interface Folks.WebServiceDetails : Object
{
  /**
   * A mapping of web service to an (unordered) set of web service addresses.
   *
   * Each mapping is from an arbitrary web service identifier to a set of web
   * service addresses for the contact, listed in no particular order.
   *
   * Web service addresses are guaranteed to be unique per web service, but
   * not necessarily unique amongst all web services.
   *
   * @since UNRELEASED
   */
  public abstract Gee.MultiMap<string, string> web_service_addresses
    {
      get; set;
    }
}
