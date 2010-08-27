AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DG_LOG_DOMAIN=\"TelepathyBackend\" \
	$(NULL)

VALAFLAGS += \
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
	tp-lowlevel.h \
	$(NULL)

libtp_lowlevel_la_CPPFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	$(AM_CPPFLAGS) \
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
INTROSPECTION_SCANNER_ARGS = --add-include-path=$(srcdir)
INTROSPECTION_COMPILER_ARGS = --includedir=$(srcdir)
CLEANFILES =

tp-lowlevel.gir: libtp-lowlevel.la
tp_lowlevel_gir_INCLUDES = GObject-2.0 TelepathyGLib-0.12
tp_lowlevel_gir_CFLAGS = $(TP_GLIB_CFLAGS)
tp_lowlevel_gir_LIBS = libtp-lowlevel.la
tp_lowlevel_gir_FILES = $(libtp_lowlevel_la_SOURCES)
tp_lowlevel_gir_NAMESPACE = Folks
INTROSPECTION_GIRS += tp-lowlevel.gir

CLEANFILES += $(gir_DATA) $(typelib_DATA)

tp-lowlevel.vapi: tp-lowlevel.gir
	$(AM_V_GEN)$(VAPIGEN) $(VALAFLAGS) --library tp-lowlevel \
		--pkg gio-2.0 \
		--pkg telepathy-glib \
		tp-lowlevel.gir

internal_vapi_files = \
	tp-lowlevel.vapi \
	$(NULL)

##################################################################
# Support library
##################################################################

pkgconfig_in = folks-telepathy.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

folks_telepathy_valasources = \
	tpf-persona.vala \
	tpf-persona-store.vala \
	tpf-logger.vala \
	$(NULL)

folks_telepathy_deps = \
	folks \
	tp-lowlevel \
	gobject-2.0 \
	gio-2.0 \
	gee-1.0 \
	dbus-glib-1 \
	telepathy-glib \
	$(NULL)

libfolks_telepathy_la_SOURCES = \
	$(folks_telepathy_valasources:.vala=.c) \
	$(libtp_lowlevel_la_SOURCES) \
	$(NULL)

libfolks_telepathy_la_CPPFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(DBUS_GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	$(AM_CPPFLAGS) \
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

folks-telepathy.h $(folks_telepathy_valasources:.vala=.c): folks-telepathy.vala.stamp

folks_telepathy_vapi_deps = \
	$(folks_telepathy_valasources) \
	$(internal_vapi_files) \
	$(NULL)

folks-telepathy.vapi folks-telepathy.vala.stamp: $(folks_telepathy_vapi_deps)
	$(VALA_V)$(VALAC) $(VALACFLAGS) $(VALAFLAGS) -H folks-telepathy.h -C \
		--library folks-telepathy \
		$(addprefix --pkg ,$(folks_telepathy_deps)) \
		$(addprefix $(srcdir)/,$(folks_telepathy_valasources))
	touch $@

##################################################################
# General
##################################################################

BUILT_SOURCES = \
	folks-telepathy.h \
	folks-telepathy.vala.stamp \
	folks-telepathy.vapi \
	tp-lowlevel.gir \
	tp-lowlevel.vapi \
	$(folks_telepathy_valasources:.vala=.c) \
	$(pkgconfig_in:.in=) \
	folks-telepathy-uninstalled.pc \
	$(NULL)

CLEANFILES += $(BUILT_SOURCES)

EXTRA_DIST = \
	$(folks_telepathy_valasources) \
	$(libtp_lowlevel_la_SOURCES) \
	$(pkgconfig_in) \
	folks-telepathy.vala.stamp \
	folks-telepathy.vapi \
	tp-lowlevel.vapi \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(folks_telepathy_valasources:.vala=.c) \
	$(NULL)

# set up the verbosity rules to avoid some build noise
# XXX: once automake >= 1.11 is common, remove these, push valasources files
# into SOURCES and add AM_PROG_VALAC to configure.ac
VALA_V = $(VALA_V_$(V))
VALA_V_ = $(VALA_V_$(AM_DEFAULT_VERBOSITY))
VALA_V_0 = @echo "  VALAC " $^;

-include $(top_srcdir)/git.mk
