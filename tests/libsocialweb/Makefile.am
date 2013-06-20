AM_CFLAGS = \
	$(ERROR_CFLAGS) \
	$(NULL)

AM_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(SW_CLIENT_CFLAGS) \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/libsocialweb/lib \
	-I$(top_srcdir)/backends/libsocialweb/lib/folks \
	-I$(top_srcdir)/tests/lib \
	-I$(top_srcdir)/tests/lib/libsocialweb \
	-include $(CONFIG_HEADER) \
	$(NULL)

LDADD = \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(top_builddir)/tests/lib/libsocialweb/libsocialweb-test.la \
	$(top_builddir)/backends/libsocialweb/lib/libfolks-libsocialweb.la \
	$(top_builddir)/folks/libfolks.la \
	$(GLIB_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(SW_CLIENT_LIBS) \
	-L$(top_srcdir)/backends/libsocialweb/lib \
	$(NULL)

AM_VALAFLAGS += \
	$(ERROR_VALAFLAGS) \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/libsocialweb/lib \
	--vapidir=$(top_srcdir)/tests/lib \
	--vapidir=$(top_srcdir)/tests/lib/libsocialweb \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg folks \
	--pkg folks-test \
	--pkg folks-libsocialweb \
	--pkg libsocialweb-client \
	--pkg libsocialweb-test \
	-g \
	$(NULL)

# in order from least to most complex
noinst_PROGRAMS = \
	dummy-lsw \
	aggregation \
	$(NULL)

TESTS_ENVIRONMENT = \
	$(top_srcdir)/tests/tools/execute-test.sh \
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
