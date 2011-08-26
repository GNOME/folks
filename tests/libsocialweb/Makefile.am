AM_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(SW_CLIENT_CFLAGS) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/libsocialweb/lib \
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

RUN_WITH_PRIVATE_BUS = $(top_srcdir)/tests/tools/with-session-bus.sh

AM_VALAFLAGS = \
	$(ERROR_VALAFLAGS) \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/libsocialweb/lib \
	--vapidir=$(top_srcdir)/tests/lib \
	--vapidir=$(top_srcdir)/tests/lib/libsocialweb \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
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

SESSION_CONF = $(top_builddir)/tests/lib/libsocialweb/session.conf
backend_store_key_file=$(srcdir)/data/backend-lsw-only.ini
TESTS_ENVIRONMENT = \
	GCONF_DEFAULT_SOURCE_PATH=@abs_top_srcdir@/tests/data/gconf.path \
	FOLKS_BACKEND_PATH=$(BACKEND_UNINST_PATH) \
	FOLKS_BACKEND_STORE_KEY_FILE_PATH=$(backend_store_key_file) \
	FOLKS_WRITEABLE_STORE=key-file \
	$(RUN_WITH_PRIVATE_BUS) \
	--config-file=$(SESSION_CONF) \
	--
TESTS = $(noinst_PROGRAMS)

dummy_lsw_SOURCES = \
	dummy-lsw.vala \
	$(NULL)

aggregation_SOURCES = \
	aggregation.vala \
	$(NULL)

CLEANFILES = \
        *.pid \
        *.address \
        $(TESTS) \
        $(NULL)

MAINTAINERCLEANFILES = \
        $(addsuffix .c,$(noinst_PROGRAMS)) \
        dummy_lsw_vala.stamp \
        aggregation_vala.stamp \
        $(NULL)

EXTRA_DIST = \
	$(MAINTAINERCLEANFILES) \
	$(backend_store_key_file) \
	$(NULL)

-include $(top_srcdir)/git.mk
-include $(top_srcdir)/check.mk
