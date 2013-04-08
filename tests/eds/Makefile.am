AM_CFLAGS = \
	$(ERROR_CFLAGS) \
	$(NULL)

AM_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(EBOOK_CFLAGS) \
	$(EDATASERVER_CFLAGS) \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/eds/lib \
	-I$(top_srcdir)/backends/eds/lib/folks \
	-I$(top_srcdir)/tests/lib \
	-I$(top_srcdir)/tests/lib/eds \
	-include $(CONFIG_HEADER) \
	$(NULL)

LDADD = \
	$(top_builddir)/tests/lib/eds/libeds-test.la \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(top_builddir)/backends/eds/lib/libfolks-eds.la
	$(top_builddir)/folks/libfolks.la \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	-L$(top_srcdir)/backends/eds/lib \
	$(NULL)

AM_VALAFLAGS += \
	$(ERROR_VALAFLAGS) \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/eds/lib \
	--vapidir=$(top_srcdir)/tests/lib \
	--vapidir=$(top_srcdir)/tests/lib/eds \
	--pkg posix \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg folks \
	--pkg folks-test \
	--pkg libebook-1.2 \
	--pkg libedataserver-1.2 \
	--pkg libxml-2.0 \
	--pkg folks-eds \
	--pkg eds-test \
	-g \
	$(NULL)

# in order from least to most complex
TESTS = \
	persona-store-tests \
	individual-retrieval \
	phone-details \
	email-details \
	name-details \
	removing-contacts \
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
	$(NULL)

RUN_WITH_PRIVATE_BUS = $(top_srcdir)/tests/tools/with-session-bus-eds.sh

TESTS_ENVIRONMENT = \
	$(RUN_WITH_PRIVATE_BUS) \
	--session \
	--

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

helper_create_many_contacts_SOURCES = \
	helper-create-many-contacts.vala \
	$(NULL)

helper_delete_contacts_SOURCES = \
	helper-delete-contacts.vala \
	$(NULL)

helper_prepare_aggregator_SOURCES = \
	helper-prepare-aggregator.vala \
	$(NULL)

CLEANFILES = \
        *.pid \
        *.address \
        $(TESTS) \
        $(NULL)

MAINTAINERCLEANFILES = \
	$(addsuffix .c,$(noinst_PROGRAMS)) \
	$(addsuffix _vala.stamp,$(subst -,_,$(noinst_PROGRAMS))) \
	$(NULL)

EXTRA_DIST = \
	$(MAINTAINERCLEANFILES) \
	$(NULL)

-include $(top_srcdir)/git.mk
-include $(top_srcdir)/check.mk
-include $(top_srcdir)/valgrind.mk
