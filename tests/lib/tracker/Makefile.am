AM_VALAFLAGS += \
	$(ERROR_VALAFLAGS) \
	--library=tracker-test \
	--header=tracker-test.h \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/tracker/lib \
	--vapidir=. \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg folks \
	--pkg tracker-sparql-$(TRACKER_SPARQL_MAJOR) \
	--pkg folks-tracker \
	-g \
	$(NULL)

noinst_LTLIBRARIES = libtracker-test.la

libtracker_test_la_SOURCES = \
	backend.vala \
	$(NULL)

libtracker_test_la_CFLAGS = \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TRACKER_SPARQL_CFLAGS) \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/tracker/lib \
	-I$(top_srcdir)/backends/tracker/lib/folks \
	$(NULL)

libtracker_test_la_LIBADD = \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(TRACKER_SPARQL_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(top_builddir)/backends/tracker/lib/libfolks-tracker.la \
	$(NULL)

# XXX: automake's Vala support should make these unnecessary
tracker-test.vapi: libtracker_test_la_vala.stamp
tracker-test.h: libtracker_test_la_vala.stamp

dist_noinst_DATA = \
	tracker-test.vapi \
	$(NULL)

MAINTAINERCLEANFILES = \
	tracker-test.vapi \
	tracker-test.h \
	$(NULL)

EXTRA_DIST = \
	tracker-test.vapi \
	tracker-test.h \
	$(NULL)

GITIGNOREFILES = \
	$(libtracker_test_la_SOURCES:.vala=.c) \
	libtracker_test_la_vala.stamp \
	$(NULL)

-include $(top_srcdir)/git.mk
