AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	$(NULL)

VALAFLAGS += $(TP_VALA_VALAFLAGS)
VALAFLAGS += --vapidir=. --vapidir=$(top_srcdir)/folks

VALAFLAGS += \
	--pkg build-conf \
	--pkg folks \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--pkg gmodule-2.0 \
	--pkg dbus-glib-1 \
	--pkg telepathy-glib \
	$(NULL)

noinst_LTLIBRARIES = libtp-lowlevel.la
folks_telepathydir = $(libdir)
folks_telepathy_LTLIBRARIES = libfolks-telepathy.la
backenddir = $(libdir)/folks/backends/telepathy
backend_LTLIBRARIES = libfolks-backend-telepathy.la

##################################################################
# Telepathy Lowlevel library
##################################################################

libtp_lowlevel_la_SOURCES = \
	tp-lowlevel.c \
	tp-lowlevel.h \
	$(NULL)

libtp_lowlevel_la_CPPFLAGS = \
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
	$(GLIB_LIBS) \
	$(TP_GLIB_LIBS) \
	$(NULL)

tp-lowlevel.gi: $(libtp-lowlevel_la_SOURCES) libtp-lowlevel.la
	$(AM_V_GEN)$(VALA_GEN_INTROSPECT) --namespace=Folks tp-lowlevel.h \
		$(GLIB_CFLAGS) $(DBUS_GLIB_CFLAGS) $(GEE_CFLAGS) \
		$(TP_VALA_CFLAGS) $(TP_GLIB_CFLAGS) -I$(top_srcdir)/folks \
		.libs/libtp-lowlevel.so > tp-lowlevel.gi

tp-lowlevel.vapi: tp-lowlevel.gi tp-lowlevel.metadata
	$(AM_V_GEN)$(VAPIGEN) $(VALAFLAGS) --library tp-lowlevel \
		--metadata=tp-lowlevel.metadata \
		tp-lowlevel.gi

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

libfolks_telepathy_la_SOURCES = \
	$(folks_telepathy_valasources:.vala=.c) \
	$(libtp_lowlevel_la_SOURCES) \
	$(NULL)

libfolks_telepathy_la_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(DBUS_GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_VALA_CFLAGS) \
	$(AM_CPPFLAGS) \
	$(NULL)

libfolks_telepathy_la_LIBADD = \
	$(GLIB_LIBS) \
	$(DBUS_GLIB_LIBS) \
	$(GEE_LIBS) \
	$(TP_VALA_LIBS) \
	$(NULL)

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
		--pkg tp-lowlevel \
		$(folks_telepathy_valasources)
	touch $@

##################################################################
# Backend
##################################################################

folks_backend_telepathy_valasources = \
	tp-backend.vala \
	tp-backend-factory.vala \
	$(NULL)

libfolks_backend_telepathy_la_SOURCES = $(folks_backend_telepathy_valasources:.vala=.c)

libfolks_backend_telepathy_la_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(DBUS_GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_VALA_CFLAGS) \
	$(AM_CPPFLAGS) \
	$(NULL)

libfolks_backend_telepathy_la_LIBADD = \
	$(GLIB_LIBS) \
	$(DBUS_GLIB_LIBS) \
	$(GEE_LIBS) \
	$(TP_VALA_LIBS) \
	-L$(abs_top_srcdir)/backends/telepathy/.libs \
	-lfolks-telepathy \
	$(NULL)

libfolks_backend_telepathy_la_LDFLAGS = -shared -fPIC -module -avoid-version

folks-backend-telepathy.h $(libfolks_backend_telepathy_la_SOURCES): folks-backend-telepathy.vala.stamp

vapi_deps = \
	folks-telepathy.vapi \
	libfolks-telepathy.la \
	$(folks_backend_telepathy_valasources) \
	$(internal_vapi_files) \
	$(NULL)

folks-backend-telepathy.vapi folks-backend-telepathy.vala.stamp: $(vapi_deps)
	$(VALA_V)$(VALAC) $(VALACFLAGS) $(VALAFLAGS) \
		-H folks-backend-telepathy.h -C \
		--library folks-backend-telepathy \
		--pkg folks \
		--pkg folks-telepathy \
		$(folks_backend_telepathy_valasources)
	touch $@

##################################################################
# General
##################################################################

BUILT_SOURCES = \
	folks-telepathy.h \
	folks-telepathy.vala.stamp \
	folks-telepathy.vapi \
	folks-backend-telepathy.h \
	folks-backend-telepathy.vala.stamp \
	folks-backend-telepathy.vapi \
	tp-lowlevel.gi \
	tp-lowlevel.vapi \
	$(folks_telepathy_valasources:.vala=.c) \
	$(libfolks_backend_telepathy_la_SOURCES) \
	$(pkgconfig_in:.in=) \
	folks-telepathy-uninstalled.pc \
	$(NULL)

CLEANFILES = $(BUILT_SOURCES)

EXTRA_DIST = \
	$(pkgconfig_in) \
	folks-telepathy.vala.stamp \
	folks-telepathy.vapi \
	folks-backend-telepathy.vala.stamp \
	folks-backend-telepathy.vapi \
	tp-lowlevel.vapi \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(folks_telepathy_valasources:.vala=.c) \
	$(libfolks_backend_telepathy_la_SOURCES) \
	$(NULL)

# set up the verbosity rules to avoid some build noise
# XXX: once automake >= 1.11 is common, remove these, push valasources files
# into SOURCES and add AM_PROG_VALAC to configure.ac
VALA_V = $(VALA_V_$(V))
VALA_V_ = $(VALA_V_$(AM_DEFAULT_VERBOSITY))
VALA_V_0 = @echo "  VALAC " $^;

-include $(top_srcdir)/git.mk
