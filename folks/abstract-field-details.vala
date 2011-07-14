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
 * Object representing any type of value that can have some vCard-like
 * parameters associated with it.
 *
 * Some contact details, like phone numbers or URLs, can have some
 * extra details associated with them.
 * For instance, a phone number expressed in vcard notation as
 * `tel;type=work,voice:(111) 555-1234` would be represented as
 * a AbstractFieldDetails with value "(111) 555-1234" and with parameters
 * `['type': ('work', 'voice')]`.
 *
 * The parameter name "TYPE" with values "work", "home", or "other" are common
 * amongst most vCard attributes (and thus most AbstractFieldDetails-derived
 * classes). A TYPE of "perf" may be used to indicate a preferred
 * AbstractFieldDetails.value amongst many. See specific classes for information
 * on additional parameters and values specific to that class.
 *
 * See [[http://www.ietf.org/rfc/rfc2426.txt|RFC2426]] for more details on
 * pre-defined parameter names and values.
 *
 * @since UNRELEASED
 */
public abstract class Folks.AbstractFieldDetails<T> : Object
{
  private T _value;
  /**
   * The value of the field.
   *
   * The value of the field, the exact type and content of which depends on what
   * the structure is used for.
   *
   * @since UNRELEASED
   */
  public virtual T @value
    {
      get { return this._value; }
      set { this._value = value; }
    }

  private MultiMap<string, string> _parameters =
      new HashMultiMap<string, string> ();
  /**
   * The parameters associated with the value.
   *
   * A multi-map of the parameters associated with
   * {@link Folks.AbstractFieldDetails.value}. The keys are the names of
   * the parameters, while the values are a list of strings.
   *
   * @since UNRELEASED
   */
  public virtual MultiMap<string, string> parameters
    {
      get { return this._parameters; }
      set
        {
          if (value == null)
            this._parameters.clear ();
          else
            this._parameters = value;
        }
    }

  /**
   * Get the values for a parameter
   *
   * @param parameter_name the parameter name
   * @return a collection of values for `parameter_name` or `null` (i.e. no
   * collection) if there are no such parameters.
   *
   * @since UNRELEASED
   */
  public Collection<string>? get_parameter_values (string parameter_name)
    {
      if (this.parameters.contains (parameter_name) == false)
        {
          return null;
        }

      return this.parameters.get (parameter_name).read_only_view;
    }

  /**
   * Add a new value for a parameter.
   *
   * If there is already a parameter called `parameter_name` then
   * `parameter_value` is added to the existing ones.
   *
   * @param parameter_name the name of the parameter
   * @param parameter_value the value to add
   *
   * @since UNRELEASED
   */
  public void add_parameter (string parameter_name, string parameter_value)
    {
      this.parameters.set (parameter_name, parameter_value);
    }

  /**
   * Set the value of a parameter.
   *
   * Sets the parameter called `parameter_name` to be `parameter_value`.
   * If there were already parameters with the same name they are replaced.
   *
   * @param parameter_name the name of the parameter
   * @param parameter_value the value to add
   *
   * @since UNRELEASED
   */
  public void set_parameter (string parameter_name, string parameter_value)
    {
      this.parameters.remove_all (parameter_name);
      this.parameters.set (parameter_name, parameter_value);
    }

  /**
   * Extend the existing parameters.
   *
   * Merge the parameters from `additional` into the existing ones.
   *
   * @param additional the parameters to add
   *
   * @since UNRELEASED
   */
  public void extend_parameters (MultiMap<string, string> additional)
    {
      foreach (var name in additional.get_keys ())
        {
          var values = additional.get (name);
          foreach (var val in values)
            {
              this.add_parameter (name, val);
            }
        }
    }

  /**
   * Remove all instances of a parameter.
   *
   * @param parameter_name the name of the parameter
   *
   * @since UNRELEASED
   */
  public void remove_parameter_all (string parameter_name)
    {
      this.parameters.remove_all (parameter_name);
    }
}
