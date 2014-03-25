include $(top_srcdir)/tests/test.mk

# This forces serialization of the tests because they run into terrible race
# conditions if run in parallel (ie, make -jN, n > 1)
#
# FIXME: https://bugzilla.gnome.org/show_bug.cgi?id=709120
.NOTPARALLEL:

AM_VALAFLAGS = \
	$(test_valaflags) \
	--vapidir=$(top_srcdir)/backends/tracker/lib \
	--vapidir=$(top_srcdir)/tests/lib/tracker \
	--pkg folks-tracker \
	--pkg tracker-sparql-$(TRACKER_SPARQL_MAJOR) \
	--pkg tracker-test \
	$(NULL)

AM_CPPFLAGS = \
	$(test_cppflags) \
	$(TRACKER_SPARQL_CFLAGS) \
	-I$(top_srcdir)/backends/tracker/lib \
	-I$(top_srcdir)/backends/tracker/lib/folks \
	-I$(top_srcdir)/tests/lib/tracker \
	$(NULL)

AM_CFLAGS = \
	$(test_cflags) \
	$(NULL)

LDADD = \
	$(AM_LDADD) \
	$(test_ldadd) \
	$(top_builddir)/tests/lib/tracker/libtracker-test.la \
	$(top_builddir)/backends/tracker/lib/libfolks-tracker.la \
	$(TRACKER_SPARQL_LIBS) \
	-L$(top_srcdir)/backends/tracker/lib \
	$(NULL)

# in order from least to most complex
noinst_PROGRAMS = \
	individual-retrieval \
	name-details-interface \
	avatar-details-interface \
	im-details-interface \
	phone-details-interface \
	email-details-interface \
	url-details-interface \
	favourite-details-interface \
	fullname-updates \
	add-contact \
	default-contact \
	remove-contact \
	nickname-updates \
	family-name-updates \
	given-name-updates \
	additional-names-updates \
	prefix-name-updates \
	suffix-name-updates \
	website-updates \
	favourite-updates \
	emails-updates \
	phones-updates \
	imaddresses-updates \
	role-details-interface \
	birthday-details-interface \
	birthday-updates \
	note-details-interface \
	gender-details-interface \
	postal-address-details-interface \
	avatar-updates \
	add-persona \
	remove-persona \
	set-nickname \
	set-favourite \
	set-phones \
	set-emails \
	set-avatar \
	set-structured-name \
	set-full-name \
	set-urls \
	set-im-addresses \
	set-postal-addresses \
	set-roles \
	set-notes \
	set-birthday \
	set-gender \
	link-personas \
	duplicated-emails \
	duplicated-phones \
	link-personas-via-local-ids \
	match-im-addresses \
	match-email-addresses \
	match-known-emails \
	match-phone-number \
	match-name \
	match-all \
	set-duplicate-email \
	set-null-avatar \
	$(NULL)

TESTS = $(noinst_PROGRAMS)

individual_retrieval_SOURCES = \
	individual-retrieval.vala \
	$(NULL)

name_details_interface_SOURCES = \
	name-details-interface.vala \
	$(NULL)

avatar_details_interface_SOURCES = \
	avatar-details-interface.vala \
	$(NULL)

im_details_interface_SOURCES = \
	im-details-interface.vala \
	$(NULL)

phone_details_interface_SOURCES = \
	phone-details-interface.vala \
	$(NULL)

email_details_interface_SOURCES = \
	email-details-interface.vala \
	$(NULL)

url_details_interface_SOURCES = \
	url-details-interface.vala \
	$(NULL)

favourite_details_interface_SOURCES = \
	favourite-details-interface.vala \
	$(NULL)

fullname_updates_SOURCES = \
	fullname-updates.vala \
	$(NULL)

add_contact_SOURCES = \
	add-contact.vala \
	$(NULL)

default_contact_SOURCES = \
	default-contact.vala \
	$(NULL)

remove_contact_SOURCES = \
	remove-contact.vala \
	$(NULL)

nickname_updates_SOURCES = \
	nickname-updates.vala \
	$(NULL)

family_name_updates_SOURCES = \
	family-name-updates.vala \
	$(NULL)

given_name_updates_SOURCES = \
	given-name-updates.vala \
	$(NULL)

additional_names_updates_SOURCES = \
	additional-names-updates.vala \
	$(NULL)

prefix_name_updates_SOURCES = \
	prefix-name-updates.vala \
	$(NULL)

suffix_name_updates_SOURCES = \
	suffix-name-updates.vala \
	$(NULL)

website_updates_SOURCES = \
	website-updates.vala \
	$(NULL)

favourite_updates_SOURCES = \
	favourite-updates.vala \
	$(NULL)

emails_updates_SOURCES = \
	emails-updates.vala \
	$(NULL)

phones_updates_SOURCES = \
	phones-updates.vala \
	$(NULL)

imaddresses_updates_SOURCES = \
	imaddresses-updates.vala \
	$(NULL)

role_details_interface_SOURCES = \
	role-details-interface.vala \
	$(NULL)

birthday_details_interface_SOURCES = \
	birthday-details-interface.vala \
	$(NULL)

birthday_updates_SOURCES = \
	birthday-updates.vala \
	$(NULL)

note_details_interface_SOURCES = \
	note-details-interface.vala \
	$(NULL)

gender_details_interface_SOURCES = \
	gender-details-interface.vala \
	$(NULL)

postal_address_details_interface_SOURCES = \
	postal-address-details-interface.vala \
	$(NULL)

avatar_updates_SOURCES = \
	avatar-updates.vala \
	$(NULL)

add_persona_SOURCES = \
	add-persona.vala \
	$(NULL)

remove_persona_SOURCES = \
	remove-persona.vala \
	$(NULL)

set_nickname_SOURCES = \
	set-nickname.vala \
	$(NULL)

set_favourite_SOURCES = \
	set-favourite.vala \
	$(NULL)

set_phones_SOURCES = \
	set-phones.vala \
	$(NULL)

set_emails_SOURCES = \
	set-emails.vala \
	$(NULL)

set_avatar_SOURCES = \
	set-avatar.vala \
	$(NULL)

set_structured_name_SOURCES = \
	set-structured-name.vala \
	$(NULL)

set_full_name_SOURCES = \
	set-full-name.vala \
	$(NULL)

set_urls_SOURCES = \
	set-urls.vala \
	$(NULL)

set_im_addresses_SOURCES = \
	set-im-addresses.vala \
	$(NULL)

set_postal_addresses_SOURCES = \
	set-postal-addresses.vala \
	$(NULL)

set_roles_SOURCES = \
	set-roles.vala \
	$(NULL)

set_notes_SOURCES = \
	set-notes.vala \
	$(NULL)

set_birthday_SOURCES = \
	set-birthday.vala \
	$(NULL)

set_gender_SOURCES = \
	set-gender.vala \
	$(NULL)

link_personas_SOURCES = \
	link-personas.vala \
	$(NULL)

duplicated_emails_SOURCES = \
	duplicated-emails.vala \
	$(NULL)

duplicated_phones_SOURCES = \
	duplicated-phones.vala \
	$(NULL)

link_personas_via_local_ids_SOURCES = \
	link-personas-via-local-ids.vala \
	$(NULL)

match_im_addresses_SOURCES = \
	match-im-addresses.vala \
	$(NULL)

match_email_addresses_SOURCES = \
	match-email-addresses.vala \
	$(NULL)

match_known_emails_SOURCES = \
	match-known-emails.vala \
	$(NULL)

match_phone_number_SOURCES = \
	match-phone-number.vala \
	$(NULL)

match_name_SOURCES = \
	match-name.vala \
	$(NULL)

match_all_SOURCES = \
	match-all.vala \
	$(NULL)

set_duplicate_email_SOURCES = \
	set-duplicate-email.vala \
	$(NULL)

set_null_avatar_SOURCES = \
	set-null-avatar.vala \
	$(NULL)

-include $(top_srcdir)/git.mk
-include $(top_srcdir)/check.mk
-include $(top_srcdir)/valgrind.mk
