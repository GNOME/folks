AM_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	-I$(top_srcdir) \
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

# --disable-warnings is necessary so that we can test deprecated API such as
# the IndividualAggregator.individuals_changed signal.
AM_VALAFLAGS = \
	$(ERROR_VALAFLAGS) \
	--disable-warnings \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/tests/lib \
	--vapidir=$(top_srcdir)/tests/lib/key-file \
	--vapidir=$(top_builddir)/tests/lib/telepathy/contactlist/ \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg folks \
	--pkg folks-test \
	--pkg kf-test \
	--pkg tp-test-contactlist \
	-g \
	$(NULL)

# in order from least to most complex
noinst_PROGRAMS = \
	abstract-field-details \
	async-locking \
	utils \
	backend-loading \
	aggregation \
	avatar-cache \
	object-cache \
	init \
	$(NULL)

SESSION_CONF = $(top_builddir)/tests/lib/telepathy/contactlist/session.conf
backend_store_key_file=$(top_srcdir)/tests/data/backend-store-all.ini
avatar_file=@abs_top_srcdir@/tests/data/avatar-01.jpg
TESTS_ENVIRONMENT = \
	FOLKS_BACKEND_PATH=$(BACKEND_UNINST_PATH) \
	FOLKS_BACKEND_STORE_KEY_FILE_PATH=$(backend_store_key_file) \
	FOLKS_PRIMARY_STORE=key-file \
	AVATAR_FILE_PATH=$(avatar_file) \
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

abstract_field_details_SOURCES = \
	abstract-field-details.vala \
	$(NULL)

async_locking_SOURCES = \
	async-locking.vala \
	$(NULL)

utils_SOURCES = \
	utils.vala \
	$(NULL)

avatar_cache_SOURCES = \
	avatar-cache.vala \
	$(NULL)

object_cache_SOURCES = \
	object-cache.vala \
	$(NULL)

init_SOURCES = \
	init.vala \
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
        abstract_field_details_vala.stamp \
        async_locking_vala.stamp \
        utils_vala.stamp \
        avatar_cache_vala.stamp \
        object_cache_vala.stamp \
        init_vala.stamp \
        $(NULL)

EXTRA_DIST = \
	$(MAINTAINERCLEANFILES) \
	$(NULL)

-include $(top_srcdir)/git.mk
-include $(top_srcdir)/valgrind.mk
-include $(top_srcdir)/check.mk
