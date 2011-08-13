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
 * Object representing a web service contact that can have some parameters
 * associated with it.
 *
 * See {@link Folks.AbstractFieldDetails}.
 *
 * @since 0.6.0
 */
public class Folks.WebServiceFieldDetails : AbstractFieldDetails<string>
{
  /**
   * Create a new WebServiceFieldDetails.
   *
   * @param value the value of the field
   * @param parameters initial parameters. See
   * {@link AbstractFieldDetails.parameters}. A `null` value is equivalent to an
   * empty map of parameters.
   *
   * @return a new WebServiceFieldDetails
   *
   * @since 0.6.0
   */
  public WebServiceFieldDetails (string value,
      MultiMap<string, string>? parameters = null)
    {
      this.value = value;
      if (parameters != null)
        this.parameters = parameters;
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  public override bool equal (AbstractFieldDetails<string> that)
    {
      return base.equal<string> (that);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  public override uint hash ()
    {
      return base.hash ();
    }
}

/**
 * Web service contact details.
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
   * @since 0.6.0
   */
  public abstract
    Gee.MultiMap<string, WebServiceFieldDetails> web_service_addresses
    {
      get; set;
    }
}
