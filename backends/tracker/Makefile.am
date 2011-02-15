SUBDIRS = lib

BACKEND_NAME = "tracker"

AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/tracker/lib \
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
	$(addprefix --pkg ,$(folks_backend_tracker_deps)) \
	$(NULL)

backenddir = $(BACKEND_DIR)/tracker
backend_LTLIBRARIES = libfolks-backend-tracker.la

libfolks_backend_tracker_la_SOURCES = \
	tr-backend.vala \
	tr-backend-factory.vala \
	$(NULL)

folks_backend_tracker_deps = \
	folks \
	folks-tracker \
	gee-1.0 \
	gio-2.0 \
	gobject-2.0 \
	tracker-sparql-0.10 \
	$(NULL)

libfolks_backend_tracker_la_CFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TRACKER_SPARQL_CFLAGS) \
	$(NULL)

libfolks_backend_tracker_la_LIBADD = \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(TRACKER_SPARQL_LIBS) \
	lib/libfolks-tracker.la \
	$(NULL)

libfolks_backend_tracker_la_LDFLAGS = -shared -fPIC -module -avoid-version

GITIGNOREFILES = \
	folks-backend-tracker.vapi \
	$(libfolks_backend_tracker_la_SOURCES:.vala=.c) \
	libfolks_backend_tracker_la_vala.stamp \
	$(NULL)

-include $(top_srcdir)/git.mk
