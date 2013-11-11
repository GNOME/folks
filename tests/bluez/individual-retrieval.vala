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

public class IndividualRetrievalTests : BluezTest.TestCase
{
  public IndividualRetrievalTests ()
    {
      base ("IndividualRetrieval");

      this.add_test ("singleton individuals", this.test_singleton_individuals);
      this.add_test ("empty address book", this.test_empty_address_book);
      this.add_test ("photos downloaded later",
          this.test_photos_downloaded_later);
    }

  /* Test that personas on a pre-existing Bluetooth device are successfully
   * downloaded and presented as singleton individuals by the aggregator. */
  public void test_singleton_individuals ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Set up the backend. */
      this.bluez_backend.create_simple_device_with_vcard (
          "BEGIN:VCARD\n" +
          "VERSION:3.0\n" +
          "N:Gump;Forrest;Mr.\n" +
          "FN:Forrest Gump\n" +
          "NICKNAME:Fir\n" +
          "TEL;TYPE=WORK,VOICE:(111) 555-1212\n" +
          "TEL;TYPE=HOME,VOICE:(404) 555-1212\n" +
          "EMAIL;TYPE=PREF,INTERNET:forrestgump@example.com\n" +
          "URL;TYPE=HOME:http://example.com/\n" +
          "END:VCARD\n" +
          "\n" +
          "BEGIN:VCARD\n" +
          "VERSION:3.0\n" +
          "N:Jones;Pam;Mrs.\n" +
          "FN:Pam Jones\n" +
          "TEL:0123456789\n" +
          "END:VCARD\n");

      /* Set up the aggregator and wait until either the expected persona are
       * seen, or the test times out and fails. */
      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_individuals.begin (aggregator,
          {"Forrest Gump", "Pam Jones"}, (o, r) =>
        {
          try
            {
              TestUtils.aggregator_prepare_and_wait_for_individuals.end (r);
            }
          catch (GLib.Error e1)
            {
              error ("Error preparing aggregator: %s", e1.message);
            }

          main_loop.quit ();
        });

      TestUtils.loop_run_with_timeout (main_loop);
    }

  /* Test that an empty address book is handled correctly. */
  public void test_empty_address_book ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Set up the backend with *no* contacts. */
      this.bluez_backend.create_simple_device_with_vcard ("");

      /* Set up the aggregator and wait until either quiescence, or the test
       * times out and fails. */
      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_quiescence.begin (aggregator,
          (o, r) =>
        {
          try
            {
              TestUtils.aggregator_prepare_and_wait_for_quiescence.end (r);
            }
          catch (GLib.Error e1)
            {
              error ("Error preparing aggregator: %s", e1.message);
            }

          main_loop.quit ();
        });

      TestUtils.loop_run_with_timeout (main_loop);

      /* Check there are no individuals. */
      assert (aggregator.individuals.size == 0);
    }

  /* Test that photos are downloaded in a second sweep of the address book. */
  public void test_photos_downloaded_later ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Set up the backend, at first with a vCard without a photo. */
      var vcard_signal_id = this.bluez_backend.create_simple_device_with_vcard (
          "BEGIN:VCARD\n" +
          "VERSION:3.0\n" +
          "N:Gump;Forrest;Mr.\n" +
          "FN:Forrest Gump\n" +
          "NICKNAME:Fir\n" +
          "TEL;TYPE=WORK,VOICE:(111) 555-1212\n" +
          "TEL;TYPE=HOME,VOICE:(404) 555-1212\n" +
          "EMAIL;TYPE=PREF,INTERNET:forrestgump@example.com\n" +
          "URL;TYPE=HOME:http://example.com/\n" +
          "END:VCARD\n");

      /* Set up the aggregator and wait until either the expected persona are
       * seen, or the test times out and fails. */
      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_individuals.begin (aggregator,
          {"Forrest Gump"}, (o, r) =>
        {
          try
            {
              TestUtils.aggregator_prepare_and_wait_for_individuals.end (r);
            }
          catch (GLib.Error e1)
            {
              error ("Error preparing aggregator: %s", e1.message);
            }

          main_loop.quit ();
        });

      TestUtils.loop_run_with_timeout (main_loop);

      /* Re-set the backend to now return a vCard with a photo (and nothing
       * else). */
      this.bluez_backend.mock_obex.disconnect (vcard_signal_id);
      this.bluez_backend.set_simple_device_vcard (
          "BEGIN:VCARD\n" +
          "VERSION:3.0\n" +
          "N:Gump;Forrest;Mr.\n" +
          "FN:Forrest Gump\n" +
          "NICKNAME:Fir\n" +
          "TEL;TYPE=WORK,VOICE:(111) 555-1212\n" +
          "TEL;TYPE=HOME,VOICE:(404) 555-1212\n" +
          "EMAIL;TYPE=PREF,INTERNET:forrestgump@example.com\n" +
          "URL;TYPE=HOME:http://example.com/\n" +
          "PHOTO;TYPE=jpeg;ENCODING=b:" +
          "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\n" +
          "END:VCARD\n");

      /* The individual should not have a photo to begin with; wait until one
       * appears. */
      assert (aggregator.individuals.size == 1);
      var iter = aggregator.individuals.map_iterator ();
      while (iter.next () == true)
        {
          var individual = iter.get_value ();
          assert (individual.avatar == null);

          /* Wait for it to change. Assert that only the avatar changes. */
          individual.notify.connect ((pspec) =>
            {
              assert (pspec.name == "avatar");
              assert (individual.avatar != null);
              main_loop.quit ();
            });
        }

      /* There’s normally a 5s wait between poll attempts in the backend, but
       * we set the FOLKS_BLUEZ_TIMEOUT_DIVISOR in the TestCase to reduce
       * this. */
      TestUtils.loop_run_with_timeout (main_loop);
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new IndividualRetrievalTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
