AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DG_LOG_DOMAIN=\"TelepathyBackend\" \
	$(NULL)

VAPIGENFLAGS += \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks

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
	$(ERROR_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	$(NULL)

# the -shared and -rpath arguments are to force it to be compiled to a .so,
# despite not being installed (it needs to be a shared library for
# vala-gen-introspect)
libtp_lowlevel_la_LDFLAGS = \
	-shared -rpath $(libdir) \
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
CLEANFILES =

tp-lowlevel.gir: libtp-lowlevel.la
tp_lowlevel_gir_INCLUDES = GObject-2.0 TelepathyGLib-0.12
tp_lowlevel_gir_CFLAGS = $(TP_GLIB_CFLAGS)
tp_lowlevel_gir_LIBS = libtp-lowlevel.la
tp_lowlevel_gir_FILES = $(libtp_lowlevel_la_SOURCES) $(tp_lowlevel_headers)
tp_lowlevel_gir_NAMESPACE = Folks
INTROSPECTION_GIRS += tp-lowlevel.gir

CLEANFILES += $(gir_DATA) $(typelib_DATA)

tp-lowlevel.vapi: tp-lowlevel.gir
	$(AM_V_GEN)$(VAPIGEN) $(VAPIGENFLAGS) \
		--library tp-lowlevel \
		--pkg gio-2.0 \
		--pkg telepathy-glib \
		tp-lowlevel.gir

##################################################################
# Support library
##################################################################

pkgconfig_in = folks-telepathy.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

libfolks_telepathy_la_vala.stamp: tp-lowlevel.vapi

folks_telepathy_valasources = \
	tpf-persona.vala \
	tpf-persona-store.vala \
	tpf-logger.vala \
	$(NULL)

libfolks_telepathy_la_SOURCES = \
	$(folks_telepathy_valasources) \
	tp-lowlevel.c \
	$(NULL)

libfolks_telepathy_la_VALAFLAGS = \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--pkg folks \
	--pkg tp-lowlevel \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--pkg dbus-glib-1 \
	--pkg telepathy-glib \
	--vapi folks-telepathy.vapi \
	-H folks-telepathy.h \
	$(NULL)

libfolks_telepathy_la_CFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(DBUS_GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	$(NULL)

libfolks_telepathy_la_LIBADD = \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(DBUS_GLIB_LIBS) \
	$(GEE_LIBS) \
	$(TP_GLIB_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(NULL)

# The quoting here is unnecessary but harmless, and has the useful side-effect
# that vim quickfix mode (:make) doesn't interpret the libtool --mode=link
# command as an error message in a bizarrely named file
libfolks_telepathy_la_LDFLAGS = \
	-version-info "$(LT_CURRENT)":"$(LT_REVISION)":"$(LT_AGE)"

folks_telepathy_includedir = $(includedir)/folks
folks_telepathy_include_HEADERS = \
	folks-telepathy.h \
	$(NULL)

vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = \
	folks-telepathy.vapi \
	folks-telepathy.deps \
	$(NULL)

##################################################################
# General
##################################################################

BUILT_SOURCES = \
	$(pkgconfig_in:.in=) \
	$(folks_telepathy_valasources:.vala=.c) \
	folks-telepathy-uninstalled.pc \
	libfolks_telepathy_la_vala.stamp \
	libtp_lowlevel_la_vala.stamp \
	tp-lowlevel.gir \
	tp-lowlevel.vapi \
	$(NULL)

CLEANFILES += \
	$(pkgconfig_in:.in=) \
	folks-telepathy-uninstalled.pc \
	$(NULL)

DISTCLEANFILES = \
	tp-lowlevel.gir \
	tp-lowlevel.vapi \
	$(NULL)

GITIGNOREFILES = \
	folks-telepathy.h \
	folks-telepathy.vapi \
	tp-lowlevel.gir \
	tp-lowlevel.vapi \
	$(NULL)

EXTRA_DIST = \
	$(libtp_lowlevel_la_SOURCES) \
	$(pkgconfig_in) \
	$(GITIGNOREFILES) \
	$(NULL)

# XXX: headers separated because automake erroneously treats all libraries in
# this file as Vala-based, so it will try (and fail) to compile the header into
# a Vala library during distcheck otherwise
noinst_HEADERS = $(tp_lowlevel_headers)

-include $(top_srcdir)/git.mk
