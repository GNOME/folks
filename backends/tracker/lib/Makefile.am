BACKEND_NAME = "tracker"

folks_trackerdir = $(libdir)
folks_tracker_LTLIBRARIES = libfolks-tracker.la

pkgconfig_in = folks-tracker.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

libfolks_tracker_la_vala.stamp:

folks_tracker_valasources = \
	trf-persona.vala \
	trf-persona-store.vala \
	trf-util.vala \
	$(NULL)

libfolks_tracker_la_SOURCES = \
	$(folks_tracker_valasources) \
	$(NULL)

libfolks_tracker_la_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--pkg folks \
	--pkg folks-generics \
	--pkg folks-internal \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg tracker-sparql-$(TRACKER_SPARQL_MAJOR) \
	--includedir folks \
	--vapi folks-tracker.vapi \
	-H folks/folks-tracker.h \
	$(NULL)

folks_backend_tracker_deps = \
	folks \
	gee-0.8 \
	gio-2.0 \
	gobject-2.0 \
	tracker-sparql-$(TRACKER_SPARQL_MAJOR) \
	$(NULL)

libfolks_tracker_la_CPPFLAGS = \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

libfolks_tracker_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TRACKER_SPARQL_CFLAGS) \
	$(NULL)

libfolks_tracker_la_LIBADD = \
	$(AM_LIBADD) \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(TRACKER_SPARQL_LIBS) \
	$(NULL)

# The quoting here is unnecessary but harmless, and has the useful side-effect
# that vim quickfix mode (:make) doesn't interpret the libtool --mode=link
# command as an error message in a bizarrely named file
libfolks_tracker_la_LDFLAGS = \
	$(AM_LDFLAGS) \
	$(CODE_COVERAGE_LDFLAGS) \
	-version-info "$(LT_CURRENT)":"$(LT_REVISION)":"$(LT_AGE)" \
	-export-symbols-regex "^(TRF|trf)_.*|" \
	$(NULL)

folks_tracker_includedir = $(includedir)/folks
folks_tracker_include_HEADERS = \
	folks/folks-tracker.h \
	$(NULL)

vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = \
	folks-tracker.vapi \
	folks-tracker.deps \
	$(NULL)

##################################################################
# General
##################################################################

MAINTAINERCLEANFILES = \
	$(folks_tracker_valasources:.vala=.c) \
	libfolks_tracker_la_vala.stamp \
	folks/folks-tracker.h \
	folks-tracker.vapi \
	$(NULL)

EXTRA_DIST = \
	$(pkgconfig_in) \
	$(MAINTAINERCLEANFILES) \
	$(NULL)

-include $(top_srcdir)/git.mk
