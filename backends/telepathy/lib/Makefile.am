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

DISTCHECK_CONFIGURE_FLAGS = --enable-introspection

-include $(INTROSPECTION_MAKEFILE)
INTROSPECTION_GIRS =
INTROSPECTION_SCANNER_ARGS = \
	$(ERROR_INTROSPECTION_SCANNER_ARGS) \
	--add-include-path=$(srcdir) \
	--warn-all \
	$(NULL)

INTROSPECTION_COMPILER_ARGS = --includedir=$(srcdir)

tp-lowlevel.gir: $(libtp_lowlevel_la_SOURCES) $(tp_lowlevel_headers) \
	libtp-lowlevel.la
tp_lowlevel_gir_INCLUDES = GObject-2.0 TelepathyGLib-0.12
tp_lowlevel_gir_CFLAGS = $(TP_GLIB_CFLAGS)
tp_lowlevel_gir_LIBS = libtp-lowlevel.la
tp_lowlevel_gir_FILES = $(libtp_lowlevel_la_SOURCES) $(tp_lowlevel_headers)
tp_lowlevel_gir_NAMESPACE = TpLowlevel
tp_lowlevel_gir_SCANNERFLAGS = --identifier-prefix=FolksTpLowlevel
INTROSPECTION_GIRS += tp-lowlevel.gir

if HAVE_VALA
tp-lowlevel.vapi: tp-lowlevel.gir
	$(MAKE) $(AM_MAKEFLAGS) tp-lowlevel.gir
	$(AM_V_GEN)$(VAPIGEN) $(VAPIGENFLAGS) \
		--library tp-lowlevel \
		--pkg gio-2.0 \
		--pkg telepathy-glib \
		tp-lowlevel.gir
	touch $@
endif

##################################################################
# Support library
##################################################################

pkgconfig_in = folks-telepathy.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

$(srcdir)/libfolks_telepathy_la_vala.stamp: tp-lowlevel.vapi

dist_noinst_DATA = \
	tp-lowlevel.gir \
	tp-lowlevel.vapi \
	$(NULL)

if NOT_RELEASE
DISTCLEANFILES = $(dist_noinst_DATA)
endif

folks_telepathy_valasources = \
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

-include $(top_srcdir)/git.mk
