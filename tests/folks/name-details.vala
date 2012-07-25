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

public class NameDetailsTests : Folks.TestCase
{
  public NameDetailsTests ()
    {
      base ("NameDetails");

      this.add_test ("structured-name-to-string",
          this.test_structured_name_to_string);
      this.add_test ("structured-name-to-string-with-format",
          this.test_structured_name_to_string_with_format);
    }

  public void test_structured_name_to_string ()
    {
      /* This test can only run in the C locale. Ignore thread safety issues
       * with calling setlocale(). In the C locale, we expect the NAME_FMT to
       * be ‘%g%t%m%t%f’, as per StructuredName.to_string(). */
      var old_locale = Intl.setlocale (LocaleCategory.ALL, null);
      Intl.setlocale (LocaleCategory.ALL, "C");

      /* Complete name. */
      var name = new StructuredName ("Family", "Given", "Additional Names",
          "Ms.", "Esq.");
      assert (name.to_string () == "Given Additional Names Family");

      /* More normal name. */
      name = new StructuredName ("Family", "Given", null, null, null);
      assert (name.to_string () == "Given Family");

      /* Restore the locale. */
      Intl.setlocale (LocaleCategory.ALL, old_locale);
    }

  private struct FormatPair
    {
      unowned string format;
      unowned string result;
    }

  public void test_structured_name_to_string_with_format ()
    {
      /* This test isn’t locale-dependent. Hooray! Set up a single
       * StructuredName and try to format it in different ways. */
      var name = new StructuredName ("Wesson-Smythe", "John Graham-Charlie",
          "De Mimsy", "Sir", "Esq.");

      const FormatPair[] tests =
       {
         /* Individual format placeholders. */
         { "%f", "Wesson-Smythe" },
         { "%F", "WESSON-SMYTHE" },
         { "%g", "John Graham-Charlie" },
         { "%G", "JGC" },
         { "%l", "" }, /* unhandled */
         { "%o", "" }, /* unhandled */
         { "%m", "De Mimsy" },
         { "%M", "DM" },
         { "%p", "" }, /* unhandled */
         { "%s", "Sir" },
         { "%S", "Sir" },
         { "%d", "Sir" },
         { "%t", "" },
         { "%p%t", "" },
         { "%f%t", "Wesson-Smythe " }, /* note the trailing space */
         { "%%", "%" },
         /* Romanised versions of the above (Romanisation is ignored). */
         { "%Rf", "Wesson-Smythe" },
         { "%RF", "WESSON-SMYTHE" },
         { "%Rg", "John Graham-Charlie" },
         { "%RG", "JGC" },
         { "%Rl", "" }, /* unhandled */
         { "%Ro", "" }, /* unhandled */
         { "%Rm", "De Mimsy" },
         { "%RM", "DM" },
         { "%Rp", "" }, /* unhandled */
         { "%Rs", "Sir" },
         { "%RS", "Sir" },
         { "%Rd", "Sir" },
         { "%Rt", "" },
         { "%Rp%t", "" },
         { "%Rf%t", "Wesson-Smythe " }, /* note the trailing space */
         /* Selected internationalised format strings from
          * http://lh.2xlibre.net/values/name_fmt/. */
         { "%d%t%g%t%m%t%f", "Sir John Graham-Charlie De Mimsy Wesson-Smythe" },
         { "%p%t%f%t%g", "Wesson-Smythe John Graham-Charlie" },
         /* yes, the ff_SN locale actually uses this: */
         { "%p%t%g%m%t%f", "John Graham-CharlieDe Mimsy Wesson-Smythe" },
         { "%g%t%f", "John Graham-Charlie Wesson-Smythe" },
         {
           /* and the fa_IR locale uses this: */
           "%d%t%s%t%f%t%g%t%m",
           "Sir Sir Wesson-Smythe John Graham-Charlie De Mimsy"
         },
         { "%f%t%d", "Wesson-Smythe Sir" },
       };

      /* Run the tests. */
      foreach (var pair in tests)
        {
          assert (name.to_string_with_format (pair.format) == pair.result);
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new NameDetailsTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
