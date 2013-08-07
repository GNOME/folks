BACKEND_NAME = "eds"

AM_CPPFLAGS = \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-include folks/redeclare-internal-api.h \
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

##################################################################
# Support library
##################################################################

pkgconfig_in = folks-eds.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

libfolks_eds_la_SOURCES = \
	edsf-namespace.vala \
	edsf-persona.vala \
	edsf-persona-store.vala \
	memory-icon.vala \
	$(NULL)

libfolks_eds_la_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--pkg folks \
	--pkg folks-generics \
	--pkg folks-internal \
	--pkg gee-0.8 \
	--pkg gio-2.0 \
	--pkg gobject-2.0 \
	--pkg libebook-1.2 \
	--pkg libebook-contacts-1.2 \
	--pkg libedataserver-1.2 \
	--pkg libxml-2.0 \
	--includedir folks \
	--gir FolksEds-$(API_VERSION_DOT).gir \
	--library folks-eds \
	--vapi folks-eds.vapi \
	-H folks/folks-eds.h \
	$(NULL)

libfolks_eds_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(EBOOK_CFLAGS) \
	$(EDATASERVER_CFLAGS) \
	$(LIBXML_CFLAGS) \
	$(NULL)

libfolks_eds_la_LIBADD = \
	$(AM_LIBADD) \
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
	$(AM_LDFLAGS) \
	$(CODE_COVERAGE_LDFLAGS) \
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
FolksEds-$(API_VERSION_DOT).gir: libfolks-eds.la
GIRS = FolksEds-$(API_VERSION_DOT).gir

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

-include ../backend.mk
-include $(top_srcdir)/git.mk
