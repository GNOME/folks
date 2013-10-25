AM_CFLAGS = \
	$(ERROR_CFLAGS) \
	$(NULL)

AM_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/tests/lib \
	-I$(top_srcdir)/tests/lib/key-file \
	-I$(top_srcdir)/tests/lib/telepathy \
	-I$(top_srcdir)/tests/lib/telepathy/contactlist \
	-include $(CONFIG_HEADER) \
	-include $(top_srcdir)/folks/warnings.h \
	$(NULL)

LDADD = \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(top_builddir)/tests/lib/key-file/libkf-test.la \
	$(top_builddir)/tests/lib/telepathy/libtpf-test.la \
	$(top_builddir)/tests/lib/telepathy/contactlist/libtp-test-contactlist.la \
	$(top_builddir)/folks/libfolks.la \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(GIO_LIBS) \
	$(TP_GLIB_LIBS) \
	$(NULL)

# --disable-warnings is necessary so that we can test deprecated API such as
# the IndividualAggregator.individuals_changed signal.
AM_VALAFLAGS += \
	$(ERROR_VALAFLAGS) \
	--disable-warnings \
	--vapidir=$(abs_srcdir) \
	--vapidir=$(abs_builddir) \
	--vapidir=$(abs_top_srcdir)/folks \
	--vapidir=$(abs_top_builddir)/folks \
	--vapidir=$(abs_top_srcdir)/tests/lib \
	--vapidir=$(abs_top_builddir)/tests/lib \
	--vapidir=$(abs_top_srcdir)/tests/lib/key-file \
	--vapidir=$(abs_top_builddir)/tests/lib/key-file \
	--vapidir=$(abs_top_srcdir)/tests/lib/telepathy \
	--vapidir=$(abs_top_builddir)/tests/lib/telepathy \
	--vapidir=$(abs_top_srcdir)/tests/lib/telepathy/contactlist/ \
	--vapidir=$(abs_top_builddir)/tests/lib/telepathy/contactlist/ \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg folks \
	--pkg folks-generics \
	--pkg folks-test \
	--pkg kf-test \
	--pkg tpf-test \
	--pkg tp-test-contactlist \
	-g \
	$(NULL)

# in order from least to most complex
noinst_PROGRAMS = \
	small-set \
	abstract-field-details \
	async-locking \
	utils \
	backend-loading \
	aggregation \
	avatar-cache \
	object-cache \
	phone-field-details \
	init \
	$(NULL)

TESTS_ENVIRONMENT = \
	$(top_srcdir)/tests/tools/execute-test.sh \
	$(NULL)

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

phone_field_details_SOURCES = \
	phone-field-details.vala \
	$(NULL)

init_SOURCES = \
	init.vala \
	$(NULL)

small_set_SOURCES = \
	small-set.vala \
	$(NULL)

-include $(top_srcdir)/git.mk
-include $(top_srcdir)/valgrind.mk
-include $(top_srcdir)/check.mk
