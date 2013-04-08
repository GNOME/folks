AM_CFLAGS = \
	$(ERROR_CFLAGS) \
	$(NULL)

AM_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/telepathy \
	-I$(top_srcdir)/backends/telepathy/lib \
	-I$(top_srcdir)/backends/telepathy/lib/folks \
	-I$(top_srcdir)/tests/lib \
	-I$(top_srcdir)/tests/lib/key-file \
	-I$(top_srcdir)/tests/lib/telepathy \
	-I$(top_srcdir)/tests/lib/telepathy/contactlist \
	-include $(CONFIG_HEADER) \
	$(NULL)

LDADD = \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(top_builddir)/tests/lib/key-file/libkf-test.la \
	$(top_builddir)/tests/lib/telepathy/libtpf-test.la \
	$(top_builddir)/tests/lib/telepathy/contactlist/libtp-test-contactlist.la \
	$(top_builddir)/backends/telepathy/lib/libfolks-telepathy.la \
	$(top_builddir)/folks/libfolks.la \
	$(GLIB_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(TP_GLIB_LIBS) \
	-L$(top_srcdir)/backends/telepathy/lib \
	$(NULL)

AM_VALAFLAGS += \
	$(ERROR_VALAFLAGS) \
	--vapidir=$(abs_top_srcdir)/tests/lib/telepathy/contactlist/ \
	--vapidir=$(abs_top_builddir)/tests/lib/telepathy/contactlist/ \
	--vapidir=$(abs_top_srcdir)/tests/lib/telepathy \
	--vapidir=$(abs_top_builddir)/tests/lib/telepathy \
	--vapidir=$(abs_top_srcdir)/tests/lib/key-file \
	--vapidir=$(abs_top_builddir)/tests/lib/key-file \
	--vapidir=$(abs_top_srcdir)/tests/lib/ \
	--vapidir=$(abs_top_builddir)/tests/lib/ \
	--vapidir=$(abs_srcdir) \
	--vapidir=$(abs_builddir) \
	--vapidir=$(abs_top_srcdir)/folks \
	--vapidir=$(abs_top_builddir)/folks \
	--vapidir=$(abs_top_srcdir)/backends/telepathy/lib \
	--vapidir=$(abs_top_builddir)/backends/telepathy/lib \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg gmodule-2.0 \
	--pkg telepathy-glib \
	--pkg folks \
	--pkg folks-telepathy \
	--pkg folks-test \
	--pkg kf-test \
	--pkg tpf-test \
	--pkg tp-test-contactlist \
	-g \
	$(NULL)

TESTS_ENVIRONMENT = \
	FOLKS_BACKEND_KEY_FILE_PATH=$(srcdir)/data/relationships-empty.ini \
	$(top_srcdir)/tests/tools/execute-test.sh \
	$(NULL)

TESTS = \
	persona-store-capabilities \
	individual-retrieval \
	individual-properties \
	$(NULL)

noinst_PROGRAMS = \
	fake-tp-backend \
	individual-zeitgeist \
	$(TESTS) \
	$(NULL)

fake_tp_backend_SOURCES = \
	fake-tp-backend.vala \
	$(NULL)

individual_retrieval_SOURCES = \
	individual-retrieval.vala \
	$(NULL)

individual_properties_SOURCES = \
	individual-properties.vala \
	$(NULL)

individual_zeitgeist_SOURCES = \
	individual-zeitgeist.vala \
	$(NULL)

persona_store_capabilities_SOURCES = \
	persona-store-capabilities.vala \
	$(NULL)

BUILT_SOURCES = \
	fake_tp_backend_vala.stamp \
	individual_properties_vala.stamp \
	individual_retrieval_vala.stamp \
	individual_zeitgeist_vala.stamp \
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
	$(srcdir)/data/relationships-empty.ini \
	$(NULL)

-include $(top_srcdir)/git.mk
-include $(top_srcdir)/valgrind.mk
-include $(top_srcdir)/check.mk
