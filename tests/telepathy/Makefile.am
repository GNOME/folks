include $(top_srcdir)/tests/test.mk

AM_VALAFLAGS = \
	$(test_valaflags) \
	--vapidir=$(abs_top_srcdir)/tests/lib/telepathy/contactlist/ \
	--vapidir=$(abs_top_builddir)/tests/lib/telepathy/contactlist/ \
	--vapidir=$(abs_top_srcdir)/tests/lib/telepathy \
	--vapidir=$(abs_top_builddir)/tests/lib/telepathy \
	--vapidir=$(abs_top_srcdir)/tests/lib/key-file \
	--vapidir=$(abs_top_builddir)/tests/lib/key-file \
	--vapidir=$(abs_top_srcdir)/backends/telepathy/lib \
	--vapidir=$(abs_top_builddir)/backends/telepathy/lib \
	--pkg telepathy-glib \
	--pkg folks-telepathy \
	--pkg kf-test \
	--pkg tpf-test \
	--pkg tp-test-contactlist \
	$(NULL)

AM_CPPFLAGS = \
	$(test_cppflags) \
	$(TP_GLIB_CFLAGS) \
	-I$(top_srcdir)/backends/telepathy \
	-I$(top_srcdir)/backends/telepathy/lib \
	-I$(top_srcdir)/backends/telepathy/lib/folks \
	-I$(top_srcdir)/tests/lib/key-file \
	-I$(top_srcdir)/tests/lib/telepathy \
	-I$(top_srcdir)/tests/lib/telepathy/contactlist \
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
	$(top_builddir)/backends/telepathy/lib/libfolks-telepathy.la \
	$(TP_GLIB_LIBS) \
	-L$(top_srcdir)/backends/telepathy/lib \
	$(NULL)

TESTS = \
	persona-store-capabilities \
	individual-retrieval \
	individual-properties \
	init \
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

init_SOURCES = \
	init.vala \
	$(NULL)

persona_store_capabilities_SOURCES = \
	persona-store-capabilities.vala \
	$(NULL)

EXTRA_DIST = \
	$(srcdir)/data/relationships-empty.ini \
	$(NULL)

-include $(top_srcdir)/git.mk
-include $(top_srcdir)/valgrind.mk
-include $(top_srcdir)/check.mk
