include $(top_srcdir)/tests/test.mk

AM_VALAFLAGS = \
	$(test_valaflags) \
	--vapidir=$(top_srcdir)/tests/lib/dummy \
	--pkg dummy-test \
	$(NULL)

AM_CPPFLAGS = \
	$(test_cppflags) \
	-I$(top_srcdir)/tests/lib/dummy \
	$(NULL)

AM_CFLAGS = \
	$(test_cflags) \
	$(NULL)

LDADD = \
	$(test_ldadd) \
	$(top_builddir)/tests/lib/dummy/libdummy-test.la \
	$(NULL)

# in order from least to most complex
TESTS = \
	individual-retrieval \
	add-persona \
	linkable-properties \
	$(NULL)

noinst_PROGRAMS = $(TESTS)

individual_retrieval_SOURCES = \
	individual-retrieval.vala \
	$(NULL)

add_persona_SOURCES = \
	add-persona.vala \
	$(NULL)

linkable_properties_SOURCES = \
	linkable-properties.vala \
	$(NULL)

-include $(top_srcdir)/git.mk
-include $(top_srcdir)/valgrind.mk
-include $(top_srcdir)/check.mk
