noinst_LTLIBRARIES = libtracker-test.la

libtracker_test_la_VALAFLAGS = \
	$(ERROR_VALAFLAGS) \
	$(AM_VALAFLAGS) \
	--library tracker-test \
	--vapi tracker-test.vapi \
	--header tracker-test.h \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/tracker/lib \
	--vapidir=$(abs_top_srcdir)/tests/lib \
	--vapidir=$(abs_top_builddir)/tests/lib \
	--vapidir=. \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg folks \
	--pkg tracker-sparql-$(TRACKER_SPARQL_MAJOR) \
	--pkg folks-tracker \
	--pkg folks-test \
	-g \
	$(NULL)

libtracker_test_la_SOURCES = \
	backend.vala \
	test-case.vala \
	$(NULL)

libtracker_test_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TRACKER_SPARQL_CFLAGS) \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/tracker/lib \
	-I$(top_srcdir)/backends/tracker/lib/folks \
	-I$(top_srcdir)/tests/lib \
	$(NULL)

libtracker_test_la_LIBADD = \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(TRACKER_SPARQL_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(top_builddir)/backends/tracker/lib/libfolks-tracker.la \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(NULL)

dist_noinst_DATA = \
	tracker-test.vapi \
	$(NULL)

EXTRA_DIST = \
	tracker-test.vapi \
	tracker-test.h \
	$(NULL)

-include $(top_srcdir)/git.mk
