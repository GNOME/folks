AM_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(EBOOK_CFLAGS) \
	$(EDATASERVER_CFLAGS) \
	$(GCONF2_CFLAGS) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/eds/lib \
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
	$(GCONF2_LIBS) \
	-L$(top_srcdir)/backends/eds/lib \
	$(NULL)

AM_VALAFLAGS = \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/eds/lib \
	--vapidir=$(top_srcdir)/tests/lib \
	--vapidir=$(top_srcdir)/tests/lib/eds \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--pkg folks \
	--pkg folks-test \
	--pkg libebook-1.2 \
	--pkg libedataserver-1.2 \
	--pkg libxml-2.0 \
	--pkg folks-eds \
	--pkg eds-test \
	--pkg gconf-2.0 \
	$(NULL)

# in order from least to most complex
noinst_PROGRAMS = \
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
	$(NULL)

RUN_WITH_PRIVATE_BUS = $(top_srcdir)/tests/tools/with-session-bus-eds.sh

backend_store_key_file=$(srcdir)/data/backend-eds-only.ini
avatar_file=@abs_top_srcdir@/tests/data/avatar-01.jpg
TESTS_ENVIRONMENT = \
	GCONF_DEFAULT_SOURCE_PATH=@abs_top_srcdir@/tests/data/gconf.path \
	FOLKS_BACKEND_PATH=$(BACKEND_UNINST_PATH) \
        FOLKS_BACKEND_STORE_KEY_FILE_PATH=$(backend_store_key_file) \
	AVATAR_FILE_PATH=$(avatar_file) \
	$(RUN_WITH_PRIVATE_BUS) \
	--session \
	--

TESTS = $(noinst_PROGRAMS)

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

link_personas_SOURCES = \
	link-personas.vala \
	$(NULL)

set_notes_SOURCES = \
	set-notes.vala \
	$(NULL)

add_contacts_stress_test_SOURCES = \
	add-contacts-stress-test.vala \
	$(NULL)

CLEANFILES = \
        *.pid \
        *.address \
        $(TESTS) \
        $(NULL)

MAINTAINERCLEANFILES = \
        $(addsuffix .c,$(noinst_PROGRAMS)) \
        persona_store_tests_vala.stamp \
        individual_retrieval_vala.stamp \
        removing_contacts_vala.stamp \
        updating_contacts_vala.stamp \
        phone_details_vala.stamp \
        name_details_vala.stamp \
        email_details_vala.stamp \
        avatar_details_vala.stamp \
        add_persona_vala.stamp \
        im_details_vala.stamp \
        postal_address_details_vala.stamp \
        remove_persona_vala.stamp \
        set_avatar_vala.stamp \
        set_emails_vala.stamp \
        set_im_addresses_vala.stamp \
        set_names_vala.stamp \
        set_structured_name_vala.stamp \
        set_phones_vala.stamp \
        set_postal_addresses_vala.stamp \
        link_personas_vala.stamp \
        set_notes_vala.stamp \
	add_contacts_stress_test_vala.stamp \
        $(NULL)

EXTRA_DIST = \
	$(MAINTAINERCLEANFILES) \
	$(backend_store_key_file) \
	$(NULL)

-include $(top_srcdir)/git.mk
-include $(top_srcdir)/check.mk
