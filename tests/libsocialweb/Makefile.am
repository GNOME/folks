include $(top_srcdir)/tests/test.mk

AM_VALAFLAGS = \
	$(test_valaflags) \
	--vapidir=$(top_srcdir)/backends/libsocialweb/lib \
	--vapidir=$(top_srcdir)/tests/lib/libsocialweb \
	--pkg folks-libsocialweb \
	--pkg libsocialweb-client \
	--pkg libsocialweb-test \
	$(NULL)

AM_CPPFLAGS = \
	$(test_cppflags) \
	$(SW_CLIENT_CFLAGS) \
	-I$(top_srcdir)/backends/libsocialweb/lib \
	-I$(top_srcdir)/backends/libsocialweb/lib/folks \
	-I$(top_srcdir)/tests/lib/libsocialweb \
	$(NULL)

AM_CFLAGS = \
	$(test_cflags) \
	$(NULL)

LDADD = \
	$(AM_LDADD) \
	$(test_ldadd) \
	$(top_builddir)/tests/lib/libsocialweb/libsocialweb-test.la \
	$(top_builddir)/backends/libsocialweb/lib/libfolks-libsocialweb.la \
	$(SW_CLIENT_LIBS) \
	-L$(top_srcdir)/backends/libsocialweb/lib \
	$(NULL)

# in order from least to most complex
noinst_PROGRAMS = \
	dummy-lsw \
	aggregation \
	$(NULL)

TESTS = $(noinst_PROGRAMS)

dummy_lsw_SOURCES = \
	dummy-lsw.vala \
	$(NULL)

aggregation_SOURCES = \
	aggregation.vala \
	$(NULL)

-include $(top_srcdir)/git.mk
-include $(top_srcdir)/check.mk
-include $(top_srcdir)/valgrind.mk
