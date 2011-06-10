AM_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/telepathy \
	-I$(top_srcdir)/backends/telepathy/lib \
	-I$(top_srcdir)/tests/lib \
	-I$(top_srcdir)/tests/lib/telepathy/contactlist \
	-include $(CONFIG_HEADER) \
	$(NULL)

LDADD = \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(top_builddir)/tests/lib/telepathy/contactlist/libtp-test-contactlist.la \
	$(top_builddir)/backends/telepathy/lib/libfolks-telepathy.la \
	$(top_builddir)/folks/libfolks.la \
	$(GLIB_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(TP_GLIB_LIBS) \
	-L$(top_srcdir)/backends/telepathy/lib \
	$(NULL)

RUN_WITH_PRIVATE_BUS = $(top_srcdir)/tests/tools/with-session-bus.sh

AM_VALAFLAGS = \
	--vapidir=$(top_builddir)/tests/lib/telepathy/contactlist/ \
	--vapidir=$(top_builddir)/tests/lib/ \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/telepathy/lib \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--pkg gmodule-2.0 \
	--pkg dbus-glib-1 \
	--pkg telepathy-glib \
	--pkg folks \
	--pkg folks-telepathy \
	--pkg folks-test \
	--pkg tp-test-contactlist \
	$(NULL)

# in order from least to most complex
noinst_PROGRAMS = \
	persona-store-capabilities \
	individual-retrieval \
	individual-properties \
	$(NULL)

SESSION_CONF = $(top_builddir)/tests/lib/telepathy/contactlist/session.conf
backend_store_key_file=$(srcdir)/data/backend-store-telepathy-only.ini
TESTS_ENVIRONMENT = \
	FOLKS_BACKEND_PATH=$(BACKEND_UNINST_PATH) \
	FOLKS_BACKEND_KEY_FILE_PATH=$(srcdir)/data/relationships-empty.ini \
	FOLKS_BACKEND_STORE_KEY_FILE_PATH=$(backend_store_key_file) \
	$(RUN_WITH_PRIVATE_BUS) \
	--config-file=$(SESSION_CONF) \
	--
TESTS = $(noinst_PROGRAMS)

individual_retrieval_SOURCES = \
	individual-retrieval.vala \
	$(NULL)

individual_properties_SOURCES = \
	individual-properties.vala \
	$(NULL)

persona_store_capabilities_SOURCES = \
	persona-store-capabilities.vala \
	$(NULL)

BUILT_SOURCES = \
	individual_properties_vala.stamp \
	individual_retrieval_vala.stamp \
	persona_store_capabilities_vala.stamp \
	$(NULL)

CLEANFILES = \
	*.pid \
	*.address \
	$(TESTS) \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(BUILT_SOURCES) \
	$(addsuffix .c,$(noinst_PROGRAMS)) \
	$(NULL)

EXTRA_DIST = \
	$(MAINTAINERCLEANFILES) \
	$(backend_store_key_file) \
	$(srcdir)/data/relationships-empty.ini \
	$(NULL)

-include $(top_srcdir)/git.mk
-include $(top_srcdir)/valgrind.mk
-include $(top_srcdir)/check.mk
