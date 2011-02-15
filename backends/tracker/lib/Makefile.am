BACKEND_NAME = "tracker"

AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

VAPIGENFLAGS += \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks

folks_trackerdir = $(libdir)
folks_tracker_LTLIBRARIES = libfolks-tracker.la

CLEANFILES =

##################################################################
# Support library
##################################################################

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
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--pkg folks \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--pkg tracker-sparql-0.10 \
	--vapi folks-tracker.vapi \
	-H folks-tracker.h \
	$(NULL)

folks_backend_tracker_deps = \
	folks \
	gee-1.0 \
	gio-2.0 \
	gobject-2.0 \
	tracker-sparql-0.10 \
	$(NULL)

libfolks_tracker_la_CFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TRACKER_SPARQL_CFLAGS) \
	$(NULL)

libfolks_tracker_la_LIBADD = \
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
	-version-info "$(LT_CURRENT)":"$(LT_REVISION)":"$(LT_AGE)" \
	-export-symbols-regex "^(TRF|trf)_.*|" \
	$(NULL)

folks_tracker_includedir = $(includedir)/folks
folks_tracker_include_HEADERS = \
	folks-tracker.h \
	$(NULL)

vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = \
	folks-tracker.vapi \
	folks-tracker.deps \
	$(NULL)

##################################################################
# General
##################################################################

CLEANFILES += \
	$(pkgconfig_in:.in=) \
	folks-tracker-uninstalled.pc \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(folks_tracker_valasources:.vala=.c) \
	libfolks_tracker_la_vala.stamp \
	folks-tracker.h \
	folks-tracker.vapi \
	$(NULL)

EXTRA_DIST = \
	$(pkgconfig_in) \
	$(MAINTAINERCLEANFILES) \
	$(NULL)

-include $(top_srcdir)/git.mk
