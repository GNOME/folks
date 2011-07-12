AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

VAPIGENFLAGS += \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	$(NULL)

folks_edsdir = $(libdir)
folks_eds_LTLIBRARIES = libfolks-eds.la

CLEANFILES =

##################################################################
# Support library
##################################################################

pkgconfig_in = folks-eds.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

libfolks_eds_la_vala.stamp:

folks_eds_valasources = \
	edsf-persona.vala \
	edsf-persona-store.vala \
	$(NULL)

libfolks_eds_la_SOURCES = \
	$(folks_eds_valasources) \
	$(NULL)

VALAFLAGS = \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	$(addprefix --pkg ,$(folks_backend_eds_deps)) \
	--includedir folks \
	--vapi folks-eds.vapi \
	-H folks/folks-eds.h \
	$(NULL)

folks_backend_eds_deps = \
	folks \
	gee-1.0 \
	gio-2.0 \
	gobject-2.0 \
	libebook-1.2 \
	libedataserver-1.2 \
	libxml-2.0 \
	$(NULL)

libfolks_eds_la_CFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(EBOOK_CFLAGS) \
	$(EDATASERVER_CFLAGS) \
	$(LIBXML_CFLAGS) \
	$(NULL)

libfolks_eds_la_LIBADD = \
	$(top_builddir)/folks/libfolks.la \
	$(EBOOK_LIBS) \
	$(EDATASERVER_LIBS) \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(LIBXML_LIBS) \
	$(NULL)

# The quoting here is unnecessary but harmless, and has the useful side-effect
# that vim quickfix mode (:make) doesn't interpret the libtool --mode=link
# command as an error message in a bizarrely named file
libfolks_eds_la_LDFLAGS = \
	-version-info "$(LT_CURRENT)":"$(LT_REVISION)":"$(LT_AGE)" \
	-export-symbols-regex "^(EDSF|edsf)_.*|" \
	$(NULL)

folks_eds_includedir = $(includedir)/folks
folks_eds_include_HEADERS = \
	folks/folks-eds.h \
	$(NULL)

vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = \
	folks-eds.vapi \
	folks-eds.deps \
	$(NULL)

##################################################################
# General
##################################################################

CLEANFILES += \
	$(pkgconfig_in:.in=) \
	folks-eds-uninstalled.pc \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(folks_eds_valasources:.vala=.c) \
	libfolks_eds_la_vala.stamp \
	folks/folks-eds.h \
	folks-eds.vapi \
	$(NULL)

EXTRA_DIST = \
	$(pkgconfig_in) \
	$(MAINTAINERCLEANFILES) \
	$(NULL)

-include ../backend.mk
-include $(top_srcdir)/git.mk
