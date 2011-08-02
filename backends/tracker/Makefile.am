SUBDIRS = lib

BACKEND_NAME = "tracker"

AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/tracker/lib \
	-I$(top_srcdir)/backends/tracker/lib/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

VALAFLAGS += \
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
	tracker-sparql-0.10 \
	$(NULL)

tracker_la_CFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TRACKER_SPARQL_CFLAGS) \
	$(NULL)

tracker_la_LIBADD = \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(TRACKER_SPARQL_LIBS) \
	lib/libfolks-tracker.la \
	$(NULL)

tracker_la_LDFLAGS = -shared -fPIC -module -avoid-version

GITIGNOREFILES = \
	folks-backend-tracker.vapi \
	$(tracker_la_SOURCES:.vala=.c) \
	tracker_la_vala.stamp \
	$(NULL)

-include $(top_srcdir)/git.mk
