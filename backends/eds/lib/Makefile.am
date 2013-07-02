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

libfolks_eds_la_vala.stamp:

folks_eds_valasources = \
	edsf-namespace.vala \
	edsf-persona.vala \
	edsf-persona-store.vala \
	memory-icon.vala \
	$(NULL)

libfolks_eds_la_SOURCES = \
	$(folks_eds_valasources) \
	$(NULL)

# XXX: it would be nice to do something like this below:
#    $(addprefix --pkg ,$(folks_backend_eds_deps)) \
# to factor out repetition, but automake's Vala support doesn't like it
# because it assumes it can simply match every flag in any _VALAFLAGS string.
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

EDSF_GIR = FolksEds-$(API_VERSION_DOT).gir
$(EDSF_GIR): libfolks-eds.la

FolksEds_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_CFLAGS = \
        $(EBOOK_CFLAGS) \
        $(EDATASERVER_CFLAGS) \
        $(NULL)
FolksEds_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_INCLUDES = \
        Gee-0.8 \
        Gio-2.0 \
        Folks-$(API_VERSION_DOT) \
        EBook-1.2 \
        EBookContacts-1.2 \
        EDataServer-1.2 \
        $(NULL)
FolksEds_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_LIBS = \
	libfolks-eds.la \
	$(top_builddir)/folks/libfolks.la \
	$(NULL)
FolksEds_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_FILES = \
$(libfolks_eds_la_SOURCES) \
        folks/folks-eds.h \
        $(NULL)
FolksEds_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_NAMESPACE = FolksEds
FolksEds_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_SCANNERFLAGS = --identifier-prefix=Edsf
INTROSPECTION_GIRS = $(EDSF_GIR)

libfolks_eds_la_VALAFLAGS += \
        --gir $(EDSF_GIR) \
        --girdir=$(abs_builddir) \
        $(NULL)

girdir = $(datadir)/gir-1.0
dist_gir_DATA = $(INTROSPECTION_GIRS)

typelibdir = $(libdir)/girepository-1.0
nodist_typelib_DATA = $(dist_gir_DATA:.gir=.typelib)

CLEANFILES += $(nodist_typelib_DATA)
MAINTAINERCLEANFILES += $(dist_gir_DATA)

##################################################################
# Common
##################################################################

-include ../backend.mk
-include $(top_srcdir)/git.mk
