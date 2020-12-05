/*
 * Copyright (C) 2011, 2015 Collabora Ltd.
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
 * Authors: Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *          Philip Withnall <philip.withnall@collabora.co.uk>
 *
 */

using EdsTest;
using Folks;
using Gee;

public class SetPropertiesTests : EdsTest.TestCase
{
  private delegate void PreCheck (Individual i);
  private delegate void SetProperty (Persona p);
  private delegate void PostCheck (Individual i);
  private struct TestDetails
    {
      string prop_name;
      unowned PreCheck pre_check;
      unowned SetProperty set_property;
      unowned PostCheck post_check;
    }

  public SetPropertiesTests ()
    {
      base ("SetProperties");

      /* TODO: Docs; don't forget to add tests below */
      TestDetails birthday_details =
        {
          "birthday", (i) =>
            {
              assert (i.birthday == null);
            },
          (p) =>
            {
              var dobj = new  DateTime.local (1980, 1, 1, 0, 0, 0.0).to_utc ();
              ((BirthdayDetails) p).birthday = dobj;
            },
          (i) =>
            {
              var dobj = new  DateTime.local (1980, 1, 1, 0, 0, 0.0).to_utc ();
              assert (i.birthday != null && i.birthday.equal (dobj));
            }
        };

      TestDetails full_name_details =
        {
          "full-name", (i) =>
            {
              assert (i.full_name == "bernie h. innocenti");
            },
          (p) =>
            {
              ((NameDetails) p).full_name = "bernie";
            },
          (i) =>
            {
              assert (i.full_name == "bernie");
            }
        };

      TestDetails gender_details =
        {
          "gender", (i) =>
            {
              assert (i.gender == Gender.UNSPECIFIED);
            },
          (p) =>
            {
              ((GenderDetails) p).gender = Gender.MALE;
            },
          (i) =>
            {
              assert (i.gender == Gender.MALE);
            }
        };

      TestDetails is_favourite_details =
        {
          "is-favourite", (i) =>
            {
              assert (!i.is_favourite);
            },
          (p) =>
            {
              ((FavouriteDetails) p).is_favourite = true;
            },
          (i) =>
            {
              assert (i.is_favourite);
            }
        };

      TestDetails nickname_details =
        {
          "nickname", (i) =>
            {
              assert (i.nickname == "");
            },
          (p) =>
            {
              ((NameDetails) p).nickname = "bernster";
            },
          (i) =>
            {
              assert (i.nickname == "bernster");
            }
        };

      TestDetails notes_details =
        {
          "notes", (i) =>
            {
              assert (i.notes.size == 0);
            },
          (p) =>
            {
              var notes = new HashSet<NoteFieldDetails> ();
              var note = new NoteFieldDetails ("This is a note.");
              notes.add (note);
              ((NoteDetails) p).notes = notes;
            },
          (i) =>
            {
              foreach (var note in i.notes)
                {
                  assert (note.equal (
                      new NoteFieldDetails ("This is a note.")));
                }
            }
        };

      TestDetails phone_numbers_details =
        {
          "phone-numbers", (i) =>
            {
              assert (i.phone_numbers.size == 0);
            },
          (p) =>
            {
              var phones = new HashSet<PhoneFieldDetails> (
                  AbstractFieldDetails<string>.hash_static,
                  AbstractFieldDetails<string>.equal_static);
              var phone_1 = new PhoneFieldDetails ("1234");
              phone_1.set_parameter (AbstractFieldDetails.PARAM_TYPE,
                  AbstractFieldDetails.PARAM_TYPE_HOME);
              phones.add (phone_1);
              ((PhoneDetails) p).phone_numbers = phones;
            },
          (i) =>
            {
              var found = false;

              foreach (var phone_fd in i.phone_numbers)
                {
                  /*
                   * If EDS is compiled with libphonenumber support, it will
                   * add an X-EVOLUTION-E164 parameter with the normalized
                   * phone number. We do not know how EDS is compiled and besides,
                   * the normalized value also depends on the current locale
                   * (the 1 in 1234 is a dialing prefix in the US and gets removed
                   * there, but not elsewhere).
                   *
                   * Therefore we cannot do a full comparison against a
                   * PhoneNumberDetails instance with the expected result,
                   * because we do not know what that is.
                   *
                   * Instead just wait for the phone number to show up,
                   * then remember the actual type and check that against the expected
                   * type after returning from the event loop.
                   */
                  if (phone_fd.value == "1234")
                    {
                      found = true;
                      var vals = phone_fd.get_parameter_values (AbstractFieldDetails.PARAM_TYPE);
                      assert (vals != null);
                      assert (vals.size == 1);
                      assert (vals.contains (AbstractFieldDetails.PARAM_TYPE_HOME));
                    }
                }

              assert (found);
            }
        };

      TestDetails postal_addresses_details =
        {
          "postal-addresses", (i) =>
            {
              assert (i.postal_addresses.size == 0);
            },
          (p) =>
            {
              var pa_fds = new HashSet<PostalAddressFieldDetails> ();
              var pa_1 = new PostalAddress ("123", "extension", "street",
                  "locality", "region", "postal code", "country", "format",
                  "123");
              var pa_fd_1 = new PostalAddressFieldDetails (pa_1);
              pa_fd_1.add_parameter (AbstractFieldDetails.PARAM_TYPE,
                  AbstractFieldDetails.PARAM_TYPE_OTHER);
              pa_fds.add (pa_fd_1);
              ((PostalAddressDetails) p).postal_addresses = pa_fds;
            },
          (i) =>
            {
              var pa = new PostalAddress ("123", "extension", "street",
                  "locality", "region", "postal code", "country", "",
                  "123");
              var expected_pa_fd = new PostalAddressFieldDetails (pa);
              expected_pa_fd.add_parameter (AbstractFieldDetails.PARAM_TYPE,
                  AbstractFieldDetails.PARAM_TYPE_OTHER);

              foreach (var pa_fd in i.postal_addresses)
                {
                  pa_fd.id = expected_pa_fd.id;
                  assert (pa_fd.equal (expected_pa_fd));
                }
            }
        };

      TestDetails roles_details =
        {
          "roles", (i) =>
            {
              assert (i.roles.size == 0);
            },
          (p) =>
            {
              var role_fds = new HashSet<RoleFieldDetails> (
                  AbstractFieldDetails<Role>.hash_static,
                  AbstractFieldDetails<Role>.equal_static);
              var r1 = new Role ("Dr.", "The Nut House Ltd");
              r1.role = "The Manager";
              var role_fd1 = new RoleFieldDetails (r1);
              role_fds.add (role_fd1);
              ((RoleDetails) p).roles = role_fds;
            },
          (i) =>
            {
              foreach (var role_fd in i.roles)
                {
                  var r1 = new Role ("Dr.", "The Nut House Ltd");
                  r1.role = "The Manager";
                  var role_fd_expected = new RoleFieldDetails (r1);
                  assert (role_fd.equal (role_fd_expected));
                }
            }
        };

      TestDetails structured_name_details =
        {
          "structured-name", (i) =>
            {
              assert (i.structured_name != null);
            },
          (p) =>
            {
              ((NameDetails) p).structured_name =
                  new StructuredName.simple ("Neutron", "Jimmy");
            },
          (i) =>
            {
              assert (i.structured_name.equal (
                  new StructuredName.simple ("Neutron", "Jimmy")));
            }
        };

      TestDetails urls_details =
        {
          "urls", (i) =>
            {
              assert (i.urls.size == 0);
            },
          (p) =>
            {
              var urls = new HashSet<UrlFieldDetails> ();

              var p1 = new UrlFieldDetails ("http://example.org");
              urls.add (p1);
              var p2 = new UrlFieldDetails ("http://extra.example.org");
              urls.add (p2);
              var p3 = new UrlFieldDetails ("http://home.example.org");
              p3.set_parameter(AbstractFieldDetails.PARAM_TYPE,
                  UrlFieldDetails.PARAM_TYPE_HOME_PAGE);
              urls.add (p3);
              var p4 = new UrlFieldDetails ("http://blog.example.org");
              p4.set_parameter(AbstractFieldDetails.PARAM_TYPE,
                  UrlFieldDetails.PARAM_TYPE_BLOG);
              urls.add (p4);

              ((UrlDetails) p).urls = urls;
            },
          (i) =>
            {
              var found_url_extra_1 = false;
              var found_url_extra_2 = false;
              var found_url_home = false;
              var found_url_blog = false;

              foreach (var url in i.urls)
                {
                  if (url.value == "http://example.org")
                      found_url_extra_1 = true;
                  else if (url.value == "http://extra.example.org")
                      found_url_extra_2 = true;
                  else if (url.value == "http://home.example.org")
                      found_url_home = true;
                  else if (url.value == "http://blog.example.org")
                      found_url_blog = true;
                }

              assert (found_url_extra_1);
              assert (found_url_extra_2);
              assert (found_url_home);
              assert (found_url_blog);
            }
        };

      /* NOTE: im-addresses and email-addresses are not tested here because
       * they are linkable properties, and hence cause re-linking in the
       * aggregator, which is too complex for this test suite. They are tested
       * in the set-emails and set-im-addresses test suites. */
      TestDetails[] properties =
        {
          birthday_details,
          full_name_details,
          gender_details,
          is_favourite_details,
          nickname_details,
          notes_details,
          phone_numbers_details,
          postal_addresses_details,
          roles_details,
          structured_name_details,
          urls_details,

/* TODO
    AntiLinkable,
    AvatarDetails,
    ExtendedInfo,
    GroupDetails,
    LocalIdDetails,
    LocationDetails,
    WebServiceDetails */
        };

      foreach (var _details in properties)
        {
          var details = _details;  /* bind the value for the closure below */
          this.add_test (details.prop_name, () =>
            {
              this._test_set_property (details.prop_name,
                  details.pre_check, details.set_property, details.post_check);
            });
        }
    }

  private void _test_set_property (string prop_name,
      PreCheck pre_check, SetProperty set_property, PostCheck post_check)
    {
      /* Set up the backend. */
      var c1 = new Gee.HashMap<string, Value?> ();
      Value? v;

      v = Value (typeof (string));
      v.set_string ("bernie h. innocenti");
      c1.set ("full_name", (owned) v);

      this.eds_backend.add_contact (c1);
      this.eds_backend.commit_contacts_to_addressbook_sync ();

      /* Set up the aggregator and wait until either the expected personas are
       * seen, or the test times out and fails. */
      var aggregator = IndividualAggregator.dup ();
      TestUtils.aggregator_prepare_and_wait_for_individuals_sync_with_timeout (
          aggregator, {"bernie h. innocenti"});

      /* Test, change, and test again the properties of the individual. */
      var i = TestUtils.get_individual_by_name (aggregator,
          "bernie h. innocenti");
      var main_loop = new MainLoop ();
      var handler = i.notify[prop_name].connect ((o, pspec) =>
        {
          Folks.Individual ind = (Folks.Individual) o;
          post_check (ind);
          main_loop.quit ();
        });

      pre_check (i);

      foreach (var p in i.personas)
          set_property (p);

      TestUtils.loop_run_with_timeout (main_loop);

      i.disconnect (handler);
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new SetPropertiesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
