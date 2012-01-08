SUBDIRS = lib

BACKEND_NAME = "tracker"

VALAFLAGS += \
	$(AM_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--vapidir=. \
	--vapidir=vapi \
	--vapidir=$(top_builddir)/backends/tracker/lib \
	--vapidir=$(top_srcdir)/folks \
	$(addprefix --pkg ,$(tracker_deps)) \
	$(NULL)

backenddir = $(BACKEND_DIR)/tracker
backend_LTLIBRARIES = tracker.la

tracker_la_SOURCES = \
	tr-backend.vala \
	tr-backend-factory.vala \
	$(NULL)

tracker_deps = \
	folks \
	folks-tracker \
	gee-1.0 \
	gio-2.0 \
	gobject-2.0 \
	tracker-sparql-0.12 \
	$(NULL)

tracker_la_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/tracker/lib \
	-I$(top_srcdir)/backends/tracker/lib/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

tracker_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TRACKER_SPARQL_CFLAGS) \
	$(NULL)

tracker_la_LIBADD = \
	$(AM_LIBADD) \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(TRACKER_SPARQL_LIBS) \
	$(top_builddir)/backends/tracker/lib/libfolks-tracker.la \
	$(NULL)

tracker_la_LDFLAGS = \
	$(AM_LDFLAGS) \
	$(CODE_COVERAGE_LDFLAGS) \
	-shared \
	-fPIC \
	-module \
	-avoid-version \
	$(NULL)

GITIGNOREFILES = \
	folks-backend-tracker.vapi \
	$(tracker_la_SOURCES:.vala=.c) \
	tracker_la_vala.stamp \
	$(NULL)

-include $(top_srcdir)/git.mk
