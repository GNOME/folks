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
 *       Travis Reitter <travis.reitter@collabora.co.uk>
 */

using GLib;
using Gee;

/**
 * Object representing any type of string value that can have some vCard-like
 * parameters associated with it.
 *
 * Some contact details, like phone numbers or URLs, can have some
 * extra details associated with them.
 * For instance, a phone number expressed in vcard notation as
 * `tel;type=work,voice:(111) 555-1234` would be represented as
 * a AbstractFieldDetails with value "(111) 555-1234" and with parameters
 * `['type': ('work', 'voice')]`.
 *
 * @since UNRELEASED
 */
public class Folks.FieldDetails : AbstractFieldDetails<string>
{
  /**
   * Create a new FieldDetails.
   *
   * @param value the value of the field
   * @return a new FieldDetails
   *
   * @since 0.3.5
   */
  public FieldDetails (string value)
    {
      this.value = value;
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
