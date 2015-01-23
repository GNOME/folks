include $(top_srcdir)/tests/test.mk

AM_VALAFLAGS = \
	$(test_valaflags) \
	--vapidir=$(top_srcdir)/tests/lib/bluez \
	--pkg bluez-test \
	--pkg folks-generics \
	$(NULL)

AM_CPPFLAGS = \
	$(test_cppflags) \
	-I$(top_srcdir)/tests/lib/bluez \
	$(NULL)

AM_CFLAGS = \
	$(test_cflags) \
	$(NULL)

LDADD = \
	$(AM_LDADD) \
	$(test_ldadd) \
	$(top_builddir)/tests/lib/bluez/libbluez-test.la \
	$(NULL)

# in order from least to most complex
all_test_programs = \
	device-properties \
	individual-retrieval \
	vcard-parsing \
	$(NULL)
installed_tests_subdirectory = bluez

device_properties_SOURCES = \
	device-properties.vala \
	$(NULL)

individual_retrieval_SOURCES = \
	individual-retrieval.vala \
	$(NULL)

vcard_parsing_SOURCES = \
	vcard-parsing.vala \
	$(NULL)

-include $(top_srcdir)/git.mk
-include $(top_srcdir)/valgrind.mk
-include $(top_srcdir)/check.mk
