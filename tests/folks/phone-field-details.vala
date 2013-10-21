/*
 * Copyright (C) 2013 Philip Withnall
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
 * Authors: Philip Withnall <philip@tecnocode.co.uk>
 */

using Gee;
using Folks;

public class PhoneFieldDetailsTests : Folks.TestCase
{
  public PhoneFieldDetailsTests ()
    {
      base ("PhoneFieldDetails");

      this.add_test ("normalisation", this.test_normalisation);
    }

  private struct NormalisationPair
    {
      unowned string unnormalised;
      unowned string normalised;
    }

  public void test_normalisation ()
    {
      /* Array of pairs of strings, mapping unnormalised phone numbers to their
       * expected normalised form. */
      const NormalisationPair[] normalisation_pairs = {
        { "1-800-123-4567", "18001234567" },
        { "+1-800-123-4567", "+18001234567" },
        { "+1-800-123-4567P123", "+18001234567P123" },
        { "+1-800-123-4567p123", "+18001234567P123" },
        { "#31#+123", "#31#+123" },
        { "*31#+123", "*31#+123" },
      };

      foreach (var s in normalisation_pairs)
        {
          var pfd1 = new PhoneFieldDetails (s.unnormalised);
          assert (pfd1.get_normalised () == s.normalised);
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new PhoneFieldDetailsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
