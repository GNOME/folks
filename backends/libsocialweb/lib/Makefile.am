BACKEND_NAME = "libsocialweb"

AM_CPPFLAGS = \
	-I$(top_srcdir) \
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

folks_libsocialwebdir = $(libdir)
folks_libsocialweb_LTLIBRARIES = libfolks-libsocialweb.la

##################################################################
# Support library
##################################################################

pkgconfig_in = folks-libsocialweb.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

libfolks_libsocialweb_la_vala.stamp:

folks_libsocialweb_valasources = \
	swf-persona.vala \
	swf-persona-store.vala \
	$(NULL)

libfolks_libsocialweb_la_SOURCES = \
	$(folks_libsocialweb_valasources) \
	$(NULL)

libfolks_libsocialweb_la_VALAFLAGS = \
	$(ERROR_VALAFLAGS) \
        --vapidir=. \
        --vapidir=$(top_srcdir)/folks \
        --pkg folks \
        --pkg folks-internal \
        --pkg folks-generics \
        --pkg gobject-2.0 \
        --pkg gio-2.0 \
        --pkg gee-0.8 \
        --pkg libsocialweb-client \
        --includedir folks \
        --vapi folks-libsocialweb.vapi \
        -H folks/folks-libsocialweb.h \
        $(NULL)

folks_backend_libsocialweb_deps = \
	folks \
	gee-0.8 \
	gio-2.0 \
	gobject-2.0 \
	libsocialweb-client \
	$(NULL)

libfolks_libsocialweb_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(GIO_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(SW_CLIENT_CFLAGS) \
	$(NULL)

libfolks_libsocialweb_la_LIBADD = \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(SW_CLIENT_LIBS) \
	$(NULL)


libfolks_libsocialweb_la_LDFLAGS = \
	$(CODE_COVERAGE_LDFLAGS) \
	-version-info "$(LT_CURRENT)":"$(LT_REVISION)":"$(LT_AGE)" \
        -export-symbols-regex "^swf_.*" \
	$(NULL)

folks_libsocialweb_includedir = $(includedir)/folks
folks_libsocialweb_include_HEADERS = \
	folks/folks-libsocialweb.h \
	$(NULL)

vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = \
	folks-libsocialweb.vapi \
	folks-libsocialweb.deps \
	$(NULL)

##################################################################
# General
##################################################################

MAINTAINERCLEANFILES = \
	$(folks_libsocialweb_valasources:.vala=.c) \
	libfolks_libsocialweb_la_vala.stamp \
	folks/folks-libsocialweb.h \
	folks-libsocialweb.vapi \
	$(NULL)

EXTRA_DIST = \
	$(pkgconfig_in) \
	$(MAINTAINERCLEANFILES) \
	$(NULL)

-include $(top_srcdir)/git.mk
