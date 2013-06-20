noinst_LTLIBRARIES = libeds-test.la

libeds_test_la_VALAFLAGS = \
	$(ERROR_VALAFLAGS) \
	$(AM_VALAFLAGS) \
	--library eds-test \
	--vapi eds-test.vapi \
	--header eds-test.h \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/eds/lib \
	--vapidir=$(top_srcdir)/backends/eds/vapi \
	--vapidir=$(abs_top_srcdir)/tests/lib \
	--vapidir=$(abs_top_builddir)/tests/lib \
	--vapidir=. \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg folks \
	--pkg libebook-1.2 \
	--pkg libedataserver-1.2 \
	--pkg libxml-2.0 \
	--pkg folks-eds \
	--pkg folks-test \
	-g \
	$(NULL)

libeds_test_la_SOURCES = \
	backend.vala \
	test-case.vala \
	$(NULL)

libeds_test_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(EBOOK_CFLAGS) \
	$(EDATASERVER_CFLAGS) \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/eds/lib \
	-I$(top_srcdir)/backends/eds/lib/folks \
	-I$(top_srcdir)/tests/lib \
	$(NULL)

libeds_test_la_LIBADD = \
	$(top_builddir)/folks/libfolks.la \
	$(top_builddir)/backends/eds/lib/libfolks-eds.la \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(EBOOK_LIBS) \
	$(EDATASERVER_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

EXTRA_DIST = \
	eds-test.vapi \
	eds-test.h \
	$(NULL)

-include $(top_srcdir)/git.mk
