/*
 * Copyright (C) 2013 Collabora Ltd.
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
 * Authors: Philip Withnall <philip.withnall@collabora.co.uk>
 */

using Gee;
using Folks;
using BluezTest;

public class VcardParsingTests : BluezTest.TestCase
{
  public VcardParsingTests ()
    {
      base ("VcardParsing");

      this.add_test ("multiple attributes", this.test_multiple_attributes);
      this.add_test ("name components", this.test_name_components);
      this.add_test ("encoding", this.test_encoding);
    }

  /* Test that vCards containing multiple attributes with the same name (e.g.
   * multiple phone numbers or e-mail addresses) are parsed correctly. */
  public void test_multiple_attributes ()
    {
      /* Set up the backend. */
      this.bluez_backend.create_simple_device_with_vcard (
          "BEGIN:VCARD\n" +
          "VERSION:3.0\n" +
          "FN:Forrest Gump\n" +
          "TEL;TYPE=WORK,VOICE:(111) 555-1212\n" +
          "TEL;TYPE=HOME,VOICE:(404) 555-1212\n" +
          "EMAIL;TYPE=PREF,INTERNET:forrestgump@example.com\n" +
          "EMAIL:test@example.com\n" +
          "URL;TYPE=HOME:http://example.com/\n" +
          "URL:http://forest.com/\n" +
          "URL:https://test.com/\n" +
          "END:VCARD\n");

      /* Set up the aggregator and wait until either the expected persona are
       * seen, or the test times out and fails. */
      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_individuals_sync_with_timeout (
          aggregator, {"Forrest Gump"});

      /* Check the properties of our friend Forrest. */
      var ind = TestUtils.get_individual_by_name (aggregator, "Forrest Gump");

      var expected_phone_numbers = new SmallSet<PhoneFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

      var expected_phone_fd = new PhoneFieldDetails ("(111) 555-1212");
      expected_phone_fd.add_parameter ("type", "work");
      expected_phone_fd.add_parameter ("type", "voice");
      expected_phone_numbers.add (expected_phone_fd);

      expected_phone_fd = new PhoneFieldDetails ("(404) 555-1212");
      expected_phone_fd.add_parameter ("type", "home");
      expected_phone_fd.add_parameter ("type", "voice");
      expected_phone_numbers.add (expected_phone_fd);

      var expected_email_addresses = new SmallSet<EmailFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

      var expected_email_fd = new EmailFieldDetails ("forrestgump@example.com");
      expected_email_fd.add_parameter ("type", "pref");
      expected_email_fd.add_parameter ("type", "internet");
      expected_email_addresses.add (expected_email_fd);

      expected_email_fd = new EmailFieldDetails ("test@example.com");
      expected_email_addresses.add (expected_email_fd);

      var expected_uris = new SmallSet<UrlFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

      var expected_uri_fd = new UrlFieldDetails ("http://example.com/");
      expected_uri_fd.add_parameter ("type", "home");
      expected_uris.add (expected_uri_fd);

      expected_uri_fd = new UrlFieldDetails ("http://forest.com/");
      expected_uris.add (expected_uri_fd);

      expected_uri_fd = new UrlFieldDetails ("https://test.com/");
      expected_uris.add (expected_uri_fd);

      assert (Utils.set_afd_equal (ind.phone_numbers, expected_phone_numbers));
      assert (Utils.set_afd_equal (ind.email_addresses,
                  expected_email_addresses));
      assert (Utils.set_afd_equal (ind.urls, expected_uris));
    }

  /* Test that vCards with different numbers of values for their N (structured
   * name) attribute are parsed correctly. */
  public void test_name_components ()
    {
      /* Set up the backend. */
      this.bluez_backend.create_simple_device_with_vcard (
          /* Valid N attributes. */
          "BEGIN:VCARD\n" +
          "VERSION:3.0\n" +
          "FN:John Public\n" +
          "N:Public;John;Quinlan;Mr.;Esq.\n" +
          "END:VCARD\n" +
          "\n" +
          "BEGIN:VCARD\n" +
          "VERSION:3.0\n" +
          "FN:John Stevenson\n" +
          "N:Stevenson;John;Philip,Paul;Dr.;Jr.,M.D.,A.C.P.\n" +
          "END:VCARD\n" +
          "\n" +
          "BEGIN:VCARD\n" +
          "VERSION:3.0\n" +
          "FN:Franco Dianno\n" +
          "N:Dianno;Franco;;;\n" +
          "END:VCARD\n" +
          "\n" +
          /* Invalid N attributes (but we should handle them anyway). */
          "BEGIN:VCARD\n" +
          "VERSION:3.0\n" +
          "FN:Amelia Smith\n" +
          "N:Smith;Amelia;David;Dr.\n" +
          "END:VCARD\n" +
          "\n" +
          "BEGIN:VCARD\n" +
          "VERSION:3.0\n" +
          "FN:Sadie Jones\n" +
          "N:Jones;Sadie;M.\n" +
          "END:VCARD\n" +
          "\n" +
          "BEGIN:VCARD\n" +
          "VERSION:3.0\n" +
          "FN:Alex Lawson\n" +
          "N:Lawson;Alex\n" +
          "END:VCARD\n" +
          "\n" +
          /* Empty FN attribute: treat it as unset. */
          "BEGIN:VCARD\n" +
          "VERSION:3.0\n" +
          "N:W;Alice;;;\n" +
          "FN:\n" +
          "TEL;TYPE=CELL:5145152\n" +
          "TEL;TYPE=VOICE:545\n" +
          "END:VCARD");

      /* Set up the aggregator and wait until either the expected persona are
       * seen, or the test times out and fails. */
      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_individuals_sync_with_timeout (
          aggregator,
          {
            "John Public",
            "John Stevenson",
            "Franco Dianno",
            "Amelia Smith",
            "Sadie Jones",
            "Alex Lawson",
            ""  /* Alice W */
          });

      /* Check the properties of our individuals. */
      var ind = TestUtils.get_individual_by_name (aggregator, "John Public");
      var expected_name =
          new StructuredName ("Public", "John", "Quinlan", "Mr.", "Esq.");
      assert (ind.structured_name.equal (expected_name));

      ind = TestUtils.get_individual_by_name (aggregator, "John Stevenson");
      expected_name =
          new StructuredName ("Stevenson", "John", "Philip,Paul", "Dr.",
              "Jr.,M.D.,A.C.P.");
      assert (ind.structured_name.equal (expected_name));

      ind = TestUtils.get_individual_by_name (aggregator, "Franco Dianno");
      expected_name = new StructuredName ("Dianno", "Franco", null, null, null);
      assert (ind.structured_name.equal (expected_name));

      ind = TestUtils.get_individual_by_name (aggregator, "Amelia Smith");
      expected_name =
          new StructuredName ("Smith", "Amelia", "David", "Dr.", null);
      assert (ind.structured_name.equal (expected_name));

      ind = TestUtils.get_individual_by_name (aggregator, "Sadie Jones");
      expected_name = new StructuredName ("Jones", "Sadie", "M.", null, null);
      assert (ind.structured_name.equal (expected_name));

      ind = TestUtils.get_individual_by_name (aggregator, "Alex Lawson");
      expected_name = new StructuredName ("Lawson", "Alex", null, null, null);
      assert (ind.structured_name.equal (expected_name));

      ind = TestUtils.get_individual_by_name (aggregator, "");
      expected_name = new StructuredName ("W", "Alice", null, null, null);
      assert (ind.structured_name.equal (expected_name));
      assert (ind.full_name == "");
    }

  /* Test that vCards with weird encodings are parsed correctly. */
  public void test_encoding ()
    {
      /* Set up the backend. */
      this.bluez_backend.create_simple_device_with_vcard (
          /* From https://bugs.kde.org/show_bug.cgi?id=98790 */
          "BEGIN:VCARD\n" +
          "VERSION:2.1\n" +
          "FN:Test 1\n" +
          "N;CHARSET=UTF-8:溌剌;元気\n" +
          "END:VCARD\n" +
          "\n" +
          /* From https://git.gnome.org/browse/evolution-data-server/tree/tests/
           *      libebook-contacts/test-vcard-parsing.c#n360 */
          "BEGIN:VCARD\n" +
          "VERSION:2.1\n" +
          "FN;ENCODING=quoted-printable:ActualValue=20=C4=9B=C5=A1" +
            "=C4=8D=C5=99=C5=BE=C3=BD=C3=A1=C3=AD=C3=A9=C3=BA=C5=AF=C3" +
            "=B3=C3=B6=C4=9A=C5=A0=C4=8C=C5=98=C5=BD=C3=9D=C3=81=C3=8D" +
            "=C3=89=C3=9A=C5=AE=C3=93=C3=96=C2=A7=201234567890=2012345" +
            "67890=201234567890=201234567890=201234567890\n" +
          "END:VCARD\n");

      /* Set up the aggregator and wait until either the expected persona are
       * seen, or the test times out and fails. */
      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_individuals_sync_with_timeout (
          aggregator,
          {
            "Test 1",
            "ActualValue ěščřžýáíéúůóöĚŠČŘŽÝÁÍÉÚŮÓÖ§ " +
              "1234567890 1234567890 1234567890 1234567890 1234567890"
          });

      /* Check the properties of our individuals. */
      var ind = TestUtils.get_individual_by_name (aggregator, "Test 1");
      var expected_name =
          new StructuredName ("溌剌", "元気", null, null, null);
      assert (ind.structured_name.equal (expected_name));

      ind =
          TestUtils.get_individual_by_name (aggregator,
              "ActualValue ěščřžýáíéúůóöĚŠČŘŽÝÁÍÉÚŮÓÖ§ " +
                  "1234567890 1234567890 1234567890 1234567890 1234567890");
      assert (ind.full_name == "ActualValue ěščřžýáíéúůóöĚŠČŘŽÝÁÍÉÚŮÓÖ§ " +
                  "1234567890 1234567890 1234567890 1234567890 1234567890");
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new VcardParsingTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
