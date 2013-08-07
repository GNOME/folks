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

libfolks_libsocialweb_la_SOURCES = \
	swf-namespace.vala \
	swf-persona.vala \
	swf-persona-store.vala \
	$(NULL)

libfolks_libsocialweb_la_VALAFLAGS = \
	$(AM_VALAFLAGS) \
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
	--gir FolksLibsocialweb-$(API_VERSION_DOT).gir \
	--library folks-libsocialweb \
	--vapi folks-libsocialweb.vapi \
	-H folks/folks-libsocialweb.h \
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

CLEANFILES =
MAINTAINERCLEANFILES =
EXTRA_DIST = \
	$(pkgconfig_in) \
	$(MAINTAINERCLEANFILES) \
	$(NULL)

##################################################################
# Introspection
##################################################################
-include $(INTROSPECTION_MAKEFILE)
INTROSPECTION_SCANNER_ARGS = \
        $(ERROR_INTROSPECTION_SCANNER_ARGS) \
        --add-include-path=$(srcdir) \
        --add-include-path=$(abs_top_builddir)/folks \
        --warn-all \
        $(NULL)

INTROSPECTION_COMPILER_ARGS = \
        --includedir=$(srcdir) \
        --includedir=$(abs_top_builddir)/folks \
        $(NULL)

if HAVE_INTROSPECTION
FolksLibsocialweb-$(API_VERSION_DOT).gir: libfolks-libsocialweb.la
GIRS = FolksLibsocialweb-$(API_VERSION_DOT).gir

girdir = $(datadir)/gir-1.0
dist_gir_DATA = $(GIRS)

MAINTAINERCLEANFILES += $(dist_gir_DATA)

typelibdir = $(libdir)/girepository-1.0
nodist_typelib_DATA = $(GIRS:.gir=.typelib)

CLEANFILES += $(nodist_typelib_DATA)
endif

##################################################################
# Common
##################################################################

-include $(top_srcdir)/git.mk
