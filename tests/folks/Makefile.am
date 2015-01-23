include $(top_srcdir)/tests/test.mk

# --disable-warnings is necessary so that we can test deprecated API such as
# the IndividualAggregator.individuals_changed signal.
AM_VALAFLAGS = \
	$(test_valaflags) \
	--disable-warnings \
	--vapidir=$(abs_top_srcdir)/tests/lib/key-file \
	--vapidir=$(abs_top_builddir)/tests/lib/key-file \
	--vapidir=$(abs_top_srcdir)/tests/lib/telepathy \
	--vapidir=$(abs_top_builddir)/tests/lib/telepathy \
	--vapidir=$(abs_top_srcdir)/tests/lib/telepathy/contactlist/ \
	--vapidir=$(abs_top_builddir)/tests/lib/telepathy/contactlist/ \
	--vapidir=$(abs_top_builddir)/tests/lib/dummy \
	--pkg folks-generics \
	--pkg kf-test \
	--pkg tpf-test \
	--pkg tp-test-contactlist \
	--pkg dummy-test \
	$(NULL)

AM_CPPFLAGS = \
	$(test_cppflags) \
	$(TP_GLIB_CFLAGS) \
	-I$(top_srcdir)/tests/lib/key-file \
	-I$(top_srcdir)/tests/lib/telepathy \
	-I$(top_srcdir)/tests/lib/telepathy/contactlist \
	-I$(top_srcdir)/tests/lib/dummy \
	$(NULL)

AM_CFLAGS = \
	$(test_cflags) \
	$(NULL)

LDADD = \
	$(AM_LDADD) \
	$(test_ldadd) \
	$(top_builddir)/tests/lib/key-file/libkf-test.la \
	$(top_builddir)/tests/lib/telepathy/libtpf-test.la \
	$(top_builddir)/tests/lib/telepathy/contactlist/libtp-test-contactlist.la \
	$(TP_GLIB_LIBS) \
	$(top_builddir)/tests/lib/dummy/libdummy-test.la \
	$(NULL)

# in order from least to most complex
all_test_programs = \
	small-set \
	abstract-field-details \
	async-locking \
	utils \
	primary-store-changes \
	backend-loading \
	aggregation \
	standalone-individuals \
	avatar-cache \
	object-cache \
	phone-field-details \
	name-details \
	init \
	$(NULL)
installed_tests_subdirectory = folks

primary_store_changes_SOURCES = \
	primary-store-changes.vala \
	$(NULL)

backend_loading_SOURCES = \
	backend-loading.vala \
	$(NULL)

aggregation_SOURCES = \
	aggregation.vala \
	$(NULL)

standalone_individuals_SOURCES = \
	standalone-individuals.vala \
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

name_details_SOURCES = \
	name-details.vala \
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
