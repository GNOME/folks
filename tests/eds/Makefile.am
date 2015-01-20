include $(top_srcdir)/tests/test.mk

# This forces serialization of the tests because they run into terrible race
# conditions if run in parallel (ie, make -jN, n > 1)
#
# FIXME: https://bugzilla.gnome.org/show_bug.cgi?id=709119
.NOTPARALLEL:

AM_VALAFLAGS = \
	$(test_valaflags) \
	--vapidir=$(top_srcdir)/backends/eds/lib \
	--vapidir=$(top_srcdir)/tests/lib/eds \
	--pkg posix \
	--pkg libebook-1.2 \
	--pkg libedataserver-1.2 \
	--pkg libxml-2.0 \
	--pkg folks-eds \
	--pkg eds-test \
	$(NULL)

AM_CPPFLAGS = \
	$(test_cppflags) \
	$(EBOOK_CFLAGS) \
	$(EDATASERVER_CFLAGS) \
	-I$(top_srcdir)/backends/eds/lib \
	-I$(top_srcdir)/backends/eds/lib/folks \
	-I$(top_srcdir)/tests/lib/eds \
	$(NULL)

AM_CFLAGS = \
	$(test_cflags) \
	$(NULL)

LDADD = \
	$(AM_LDADD) \
	$(test_ldadd) \
	$(top_builddir)/tests/lib/eds/libeds-test.la \
	$(top_builddir)/backends/eds/lib/libfolks-eds.la \
	-L$(top_srcdir)/backends/eds/lib \
	$(NULL)

# in order from least to most complex
TESTS = \
	persona-store-tests \
	individual-retrieval \
	phone-details \
	email-details \
	name-details \
	removing-contacts \
	updating-phones \
	updating-contacts \
	avatar-details \
	add-persona \
	im-details \
	postal-address-details \
	remove-persona \
	set-avatar \
	set-emails \
	set-im-addresses \
	set-names \
	set-structured-name \
	set-phones \
	set-postal-addresses \
	link-personas \
	set-notes \
	add-contacts-stress-test \
	set-gender \
	set-urls \
	set-properties-race \
	set-birthday \
	set-roles \
	linkable-properties \
	link-personas-diff-stores \
	store-removed \
	anti-linking \
	enable-disable-stores \
	set-is-favourite \
	perf \
	extended-info \
	$(NULL)

noinst_PROGRAMS = \
	$(TESTS) \
	helper-create-many-contacts \
	helper-delete-contacts \
	helper-prepare-aggregator \
	$(NULL)

anti_linking_SOURCES = \
	anti-linking.vala \
	$(NULL)

persona_store_tests_SOURCES = \
	persona-store-tests.vala \
	$(NULL)

individual_retrieval_SOURCES = \
	individual-retrieval.vala \
	$(NULL)

removing_contacts_SOURCES = \
	removing-contacts.vala \
	$(NULL)

updating_phones_SOURCES = \
	updating-phones.vala \
	$(NULL)

updating_contacts_SOURCES = \
	updating-contacts.vala \
	$(NULL)

phone_details_SOURCES = \
	phone-details.vala \
	$(NULL)

email_details_SOURCES = \
	email-details.vala \
	$(NULL)

name_details_SOURCES = \
	name-details.vala \
	$(NULL)

avatar_details_SOURCES = \
	avatar-details.vala \
	$(NULL)

add_persona_SOURCES = \
	add-persona.vala \
	$(NULL)

im_details_SOURCES = \
	im-details.vala \
	$(NULL)

postal_address_details_SOURCES = \
	postal-address-details.vala \
	$(NULL)

remove_persona_SOURCES = \
	remove-persona.vala \
	$(NULL)

set_avatar_SOURCES = \
	set-avatar.vala \
	$(NULL)

linkable_properties_SOURCES = \
	linkable-properties.vala \
	$(NULL)

set_emails_SOURCES = \
	set-emails.vala \
	$(NULL)

set_im_addresses_SOURCES = \
	set-im-addresses.vala \
	$(NULL)

set_names_SOURCES = \
	set-names.vala \
	$(NULL)

set_structured_name_SOURCES = \
	set-structured-name.vala \
	$(NULL)

set_phones_SOURCES = \
	set-phones.vala \
	$(NULL)

set_postal_addresses_SOURCES = \
	set-postal-addresses.vala \
	$(NULL)

set_properties_race_SOURCES = \
	set-properties-race.vala \
	$(NULL)

link_personas_SOURCES = \
	link-personas.vala \
	$(NULL)

set_notes_SOURCES = \
	set-notes.vala \
	$(NULL)

add_contacts_stress_test_SOURCES = \
	add-contacts-stress-test.vala \
	$(NULL)

set_gender_SOURCES = \
	set-gender.vala \
	$(NULL)

set_urls_SOURCES = \
	set-urls.vala \
	$(NULL)

set_birthday_SOURCES = \
	set-birthday.vala \
	$(NULL)

set_roles_SOURCES = \
	set-roles.vala \
	$(NULL)

link_personas_diff_stores_SOURCES = \
	link-personas-diff-stores.vala \
	$(NULL)

enable_disable_stores_SOURCES = \
	enable-disable-stores.vala \
	$(NULL)

set_is_favourite_SOURCES = \
	set-is-favourite.vala \
	$(NULL)

store_removed_SOURCES = \
	store-removed.vala \
	$(NULL)

perf_SOURCES = \
	perf.vala \
	$(NULL)

extended_info_SOURCES = \
	extended-info.vala
	$(NULL)

helper_create_many_contacts_SOURCES = \
	helper-create-many-contacts.vala \
	$(NULL)

helper_delete_contacts_SOURCES = \
	helper-delete-contacts.vala \
	$(NULL)

helper_prepare_aggregator_SOURCES = \
	helper-prepare-aggregator.vala \
	$(NULL)

-include $(top_srcdir)/git.mk
-include $(top_srcdir)/check.mk
-include $(top_srcdir)/valgrind.mk
