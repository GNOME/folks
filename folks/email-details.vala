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
 *       Marco Barisione <marco.barisione@collabora.co.uk>
 */

using GLib;
using Gee;

/**
 * Object representing a email address that can have some parameters
 * associated with it.
 *
 * See {@link Folks.AbstractFieldDetails} for details on common parameter names
 * and values.
 *
 * @since UNRELEASED
 */
public class Folks.EmailFieldDetails : AbstractFieldDetails<string>
{
  /**
   * Create a new EmailFieldDetails.
   *
   * @param value the value of the field
   * @param parameters initial parameters. See
   * {@link AbstractFieldDetails.parameters}. A `null` value is equivalent to an
   * empty map of parameters.
   *
   *
   * @return a new EmailFieldDetails
   *
   * @since UNRELEASED
   */
  public EmailFieldDetails (string value,
      MultiMap<string, string>? parameters = null)
    {
      this.value = value;
      if (parameters != null)
        this.parameters = parameters;
    }

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public override bool equal (AbstractFieldDetails<string> that)
    {
      return base.equal<string> (that);
    }

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public override uint hash ()
    {
      return base.hash ();
    }
}

/**
 * Interface for classes that have email addresses, such as {@link Persona}
 * and {@link Individual}.
 *
 * @since 0.3.5
 */
public interface Folks.EmailDetails : Object
{
  /**
   * The email addresses of the contact.
   *
   * Each of the values in this property contains just an e-mail address (e.g.
   * “foo@bar.com”), rather than any other way of formatting an e-mail address
   * (such as “John Smith <foo@bar.com>”).
   *
   * @since UNRELEASED
   */
  public abstract Set<EmailFieldDetails> email_addresses { get; set; }
}
