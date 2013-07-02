BACKEND_NAME = "telepathy"

AM_CPPFLAGS = \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

VAPIGENFLAGS += \
	--vapidir=$(abs_builddir) \
	--vapidir=$(abs_srcdir) \
	--vapidir=$(abs_top_builddir)/folks \
	--vapidir=$(abs_top_srcdir)/folks \
	$(NULL)

noinst_LTLIBRARIES = libtp-lowlevel.la
folks_telepathydir = $(libdir)
folks_telepathy_LTLIBRARIES = libfolks-telepathy.la

dist_noinst_DATA =

##################################################################
# Telepathy Lowlevel library
##################################################################

libtp_lowlevel_la_SOURCES = \
	tp-lowlevel.c \
	$(NULL)

tp_lowlevel_headers = tp-lowlevel.h

libtp_lowlevel_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(C_ERROR_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	$(NULL)

# the -shared and -rpath arguments are to force it to be compiled to a .so,
# despite not being installed (it needs to be a shared library for
# vala-gen-introspect)
libtp_lowlevel_la_LDFLAGS = \
	$(AM_LDFLAGS) \
	$(CODE_COVERAGE_LDFLAGS) \
	-shared \
	-rpath $(libdir) \
	-avoid-version \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(TP_GLIB_LIBS) \
	$(NULL)

if HAVE_VALA
tp-lowlevel.vapi: TpLowlevel-$(API_VERSION_DOT).gir
	$(MAKE) $(AM_MAKEFLAGS) TpLowlevel-$(API_VERSION_DOT).gir
	$(AM_V_GEN)$(VAPIGEN) $(VAPIGENFLAGS) \
		--library tp-lowlevel \
		--pkg gio-2.0 \
		--pkg telepathy-glib \
		TpLowlevel-$(API_VERSION_DOT).gir
	touch $@
endif

dist_noinst_DATA += tp-lowlevel.vapi

##################################################################
# Support library
##################################################################

pkgconfig_in = folks-telepathy.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

$(srcdir)/libfolks_telepathy_la_vala.stamp: tp-lowlevel.vapi

folks_telepathy_valasources = \
	tpf-namespace.vala \
	tpf-persona.vala \
	tpf-persona-store.vala \
	tpf-logger.vala \
	tpf-persona-store-cache.vala \
	$(NULL)

libfolks_telepathy_la_SOURCES = \
	$(folks_telepathy_valasources) \
	tp-lowlevel.c \
	$(NULL)

libfolks_telepathy_la_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	$(ZEITGEIST_VALAFLAGS) \
	--library=folks-telepathy \
	--vapidir=$(abs_srcdir) \
	--vapidir=$(abs_builddir) \
	--vapidir=$(abs_top_srcdir)/folks \
	--vapidir=$(abs_top_builddir)/folks \
	--pkg folks \
	--pkg folks-generics \
	--pkg folks-internal \
	--pkg tp-lowlevel \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg telepathy-glib \
	$(ZEITGEIST_PKG) \
	--includedir folks \
	--vapi folks-telepathy.vapi \
	-H folks/folks-telepathy.h \
	$(NULL)

libfolks_telepathy_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	$(ZEITGEIST_CFLAGS) \
	$(NULL)

libfolks_telepathy_la_LIBADD = \
	$(AM_LIBADD) \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(TP_GLIB_LIBS) \
	$(ZEITGEIST_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(NULL)

# The quoting here is unnecessary but harmless, and has the useful side-effect
# that vim quickfix mode (:make) doesn't interpret the libtool --mode=link
# command as an error message in a bizarrely named file
libfolks_telepathy_la_LDFLAGS = \
	$(AM_LDFLAGS) \
	$(CODE_COVERAGE_LDFLAGS) \
	-version-info "$(LT_CURRENT)":"$(LT_REVISION)":"$(LT_AGE)" \
	-export-symbols-regex "^tpf_.*" \
	$(NULL)

folks_telepathy_includedir = $(includedir)/folks
folks_telepathy_include_HEADERS = \
	folks/folks-telepathy.h \
	$(NULL)

vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = \
	folks-telepathy.vapi \
	folks-telepathy.deps \
	$(NULL)

##################################################################
# General
##################################################################

if NOT_RELEASE
DISTCLEANFILES = $(dist_noinst_DATA)
endif

CLEANFILES =
MAINTAINERCLEANFILES = \
	$(folks_telepathy_valasources:.vala=.c) \
	libfolks_telepathy_la_vala.stamp \
	folks/folks-telepathy.h \
	folks-telepathy.vapi \
	$(dist_noinst_DATA) \
	$(NULL)

EXTRA_DIST = \
	$(libtp_lowlevel_la_SOURCES) \
	$(pkgconfig_in) \
	$(MAINTAINERCLEANFILES) \
	$(NULL)

# XXX: headers separated because automake erroneously treats all libraries in
# this file as Vala-based, so it will try (and fail) to compile the header into
# a Vala library during distcheck otherwise
noinst_HEADERS = $(tp_lowlevel_headers)

##################################################################
# Introspection
##################################################################

-include $(INTROSPECTION_MAKEFILE)
INTROSPECTION_GIRS =
INTROSPECTION_SCANNER_ARGS = \
        $(ERROR_INTROSPECTION_SCANNER_ARGS) \
        --add-include-path=$(srcdir) \
        --add-include-path=$(abs_top_builddir)/folks \
        --warn-all \
        $(NULL)

DISTCHECK_CONFIGURE_FLAGS = --enable-introspection

INTROSPECTION_COMPILER_ARGS = \
        --includedir=$(srcdir) \
        --includedir=$(abs_top_builddir)/folks \
        $(NULL)

#------------------------------------
# TpLowlevel
#------------------------------------
TpLowlevel_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_INCLUDES = GObject-2.0 TelepathyGLib-0.12
TpLowlevel_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_CFLAGS = $(TP_GLIB_CFLAGS)
TpLowlevel_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_LIBS = libtp-lowlevel.la
TpLowlevel_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_FILES = $(libtp_lowlevel_la_SOURCES) $(tp_lowlevel_headers)
TpLowlevel_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_NAMESPACE = TpLowlevel
TpLowlevel_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_SCANNERFLAGS = \
        --identifier-prefix=FolksTpLowlevel \
        --c-include="tp-lowlevel.h" \
        $(NULL)
TpLowlevel_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_VERSION = $(API_VERSION_DOT)
INTROSPECTION_GIRS += TpLowlevel-$(API_VERSION_DOT).gir
dist_noinst_DATA += TpLowlevel-$(API_VERSION_DOT).gir

#------------------------------------
# Folks Telepathy
#------------------------------------
TPF_GIR = FolksTelepathy-$(API_VERSION_DOT).gir
$(TPF_GIR): libfolks-telepathy.la

FolksTelepathy_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_CFLAGS = $(TP_GLIB_CFLAGS)
# Note that we don't actually include TpLowlevel*.gir because we don't want to
# make it a public dependency
FolksTelepathy_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_INCLUDES = \
        Gee-0.8 \
        Gio-2.0 \
        Folks-$(API_VERSION_DOT) \
        TelepathyGLib-0.12 \
        $(NULL)
FolksTelepathy_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_LIBS = \
	libfolks-telepathy.la \
        $(top_builddir)/folks/libfolks.la \
        $(NULL)
FolksTelepathy_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_FILES = \
        $(libfolks_telepathy_la_SOURCES) \
        folks/folks-telepathy.h \
        $(NULL)
FolksTelepathy_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_NAMESPACE = FolksTelepathy
FolksTelepathy_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_SCANNERFLAGS = --identifier-prefix=Tpf
INTROSPECTION_GIRS += $(TPF_GIR)

libfolks_telepathy_la_VALAFLAGS += \
        --gir=$(TPF_GIR) \
        --girdir=$(abs_builddir) \
        $(NULL)

#------------------------------------
# General
#------------------------------------
girdir = $(datadir)/gir-1.0
dist_gir_DATA = $(INTROSPECTION_GIRS)

typelibdir = $(libdir)/girepository-1.0
nodist_typelib_DATA = $(dist_gir_DATA:.gir=.typelib)

CLEANFILES += $(nodist_typelib_DATA)
MAINTAINERCLEANFILES += $(dist_gir_DATA)

##################################################################
# Common
##################################################################

-include $(top_srcdir)/git.mk
