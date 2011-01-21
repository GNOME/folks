AM_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/tests/lib \
	-I$(top_srcdir)/tests/lib/key-file \
	-I$(top_srcdir)/tests/lib/telepathy/contactlist \
	-include $(CONFIG_HEADER) \
	$(NULL)

LDADD = \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(top_builddir)/tests/lib/key-file/libkf-test.la \
	$(top_builddir)/tests/lib/telepathy/contactlist/libtp-test-contactlist.la \
	$(top_builddir)/folks/libfolks.la \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(GIO_LIBS) \
	$(TP_GLIB_LIBS) \
	$(NULL)

RUN_WITH_PRIVATE_BUS = $(top_srcdir)/tests/tools/with-session-bus.sh

AM_VALAFLAGS = \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/tests/lib \
	--vapidir=$(top_srcdir)/tests/lib/key-file \
	--vapidir=$(top_builddir)/tests/lib/telepathy/contactlist/ \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--pkg folks \
	--pkg folks-test \
	--pkg kf-test \
	--pkg tp-test-contactlist \
	$(NULL)

# in order from least to most complex
noinst_PROGRAMS = \
	field-details \
	linked-hash-set \
	backend-loading \
	aggregation \
	$(NULL)

SESSION_CONF = $(top_builddir)/tests/lib/telepathy/contactlist/session.conf
backend_store_key_file=$(top_srcdir)/tests/data/backend-store-all.ini
TESTS_ENVIRONMENT = \
	FOLKS_BACKEND_PATH=$(BACKEND_UNINST_PATH) \
	FOLKS_BACKEND_STORE_KEY_FILE_PATH=$(backend_store_key_file) \
	$(RUN_WITH_PRIVATE_BUS) \
	--config-file=$(SESSION_CONF) \
	--

TESTS = $(noinst_PROGRAMS)

backend_loading_SOURCES = \
	backend-loading.vala \
	$(NULL)

aggregation_SOURCES = \
	aggregation.vala \
	$(NULL)

field_details_SOURCES = \
	field-details.vala \
	$(NULL)

linked_hash_set_SOURCES = \
	linked-hash-set.vala \
	$(NULL)

CLEANFILES = \
        *.pid \
        *.address \
        $(TESTS) \
        $(NULL)

MAINTAINERCLEANFILES = \
        $(addsuffix .c,$(noinst_PROGRAMS)) \
        backend_loading_vala.stamp \
        aggregation_vala.stamp \
        field_details_vala.stamp \
        linked_hash_set_vala.stamp \
        $(NULL)

EXTRA_DIST = \
	$(MAINTAINERCLEANFILES) \
	$(NULL)

-include $(top_srcdir)/git.mk
-include $(top_srcdir)/valgrind.mk
