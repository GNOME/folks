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
 *       Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 */

using GLib;
using Gee;

/**
 * Interface for classes that can provide a phone number, such as
 * {@link Persona} and {@link Individual}.
 *
 * @since 0.3.5
 */
public interface Folks.PhoneDetails : Object
{
  private const string[] _extension_chars = { "p", "P", "w", "W", "x", "X" };
  private const string[] _common_delimiters = { ",", ".", "(", ")", "-", " ",
      "\t", "/" };
  private const string[] _valid_digits = { "#", "*", "0", "1", "2", "3", "4",
      "5", "6", "7", "8", "9" };

  /**
   * The phone numbers of the contact.
   *
   * A list of phone numbers associated to the contact.
   *
   * @since 0.5.1
   */
  public abstract Set<FieldDetails> phone_numbers { get; set; }

  /**
   * Normalise and compare two phone numbers.
   * @since 0.5.0
   */
  public static bool numbers_equal (string number1, string number2)
    {
      var n1 =
        PhoneDetails.drop_extension (PhoneDetails.normalise_number (number1));
      var n2 =
        PhoneDetails.drop_extension (PhoneDetails.normalise_number (number2));

      /* Based on http://blog.barisione.org/2010-06/handling-phone-numbers/ */
      if (n1.length >= 7 && n2.length >= 7)
        {
          var n1_reduced = n1.slice (-7, n1.length);
          var n2_reduced = n2.slice (-7, n2.length);

          debug ("[PhoneDetails.equal] Comparing %s with %s",
              n1_reduced, n2_reduced);

          return  n1_reduced == n2_reduced;
        }

      return false;
    }

  /**
   * Normalise a given phone number.
   *
   * Typical normalisations:
   *
   *  - 1-800-123-4567 --> 18001234567
   *  - +1-800-123-4567 --> 18001234567
   *  - +1-800-123-4567P123 --> 18001234567P123
   *
   * @since 0.5.0
   */
  public static string normalise_number (string number)
    {
      string normalised_number = "";

      for (int i=0; i<number.length; i++)
        {
          var digit = number.slice (i, i + 1);

          if (i == 0 && digit == "+")
            {
              /* we drop the initial + */
              continue;
            }
          else if (PhoneDetails.is_extension_digit (digit) ||
              PhoneDetails.is_valid_digit (digit))
            {
              /* lets keep valid digits */
              normalised_number += digit;
            }
          else if (PhoneDetails.is_common_delimiter (digit))
            {
              continue;
            }
          else
            {
              debug ("[PhoneDetails.normalise] unknown digit: %s", digit);
            }
       }

      return normalised_number.up ();
    }

  internal static bool is_extension_digit (string digit)
    {
      return digit in PhoneDetails._extension_chars;
    }

  internal static bool is_valid_digit (string digit)
    {
      return digit in PhoneDetails._valid_digits;
    }

  internal static bool is_common_delimiter  (string digit)
    {
      return digit in PhoneDetails._common_delimiters;
    }

  /**
   * Returns the given number without it's extension (if any).
   *
   * @since 0.5.0
   */
  internal static string drop_extension (string number)
    {
      for (var i=0; i < PhoneDetails._extension_chars.length; i++)
        {
          if (number.index_of (PhoneDetails._extension_chars[i]) >= 0)
            {
              return number.split (PhoneDetails._extension_chars[i])[0];
            }
        }

      return number;
    }
}
