AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	$(NULL)

# this seems to work, even if vim's syntax highlighting suggests otherwise
VALAFLAGS += $(shell PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) pkg-config --variable=valaflags telepathy-vala)
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
	$(VGI_V)$(VALA_GEN_INTROSPECT) --namespace=Folks tp-lowlevel.h \
		$(shell pkg-config telepathy-glib --cflags) \
		$(GLIB_CFLAGS) $(DBUS_GLIB_CFLAGS) $(GEE_CFLAGS) \
		$(TP_VALA_CFLAGS) -I$(top_srcdir)/folks \
		.libs/libtp-lowlevel.so > tp-lowlevel.gi

tp-lowlevel.vapi: tp-lowlevel.gi tp-lowlevel.metadata
	$(VAPIGEN_V)$(VAPIGEN) $(VALAFLAGS) --library tp-lowlevel \
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

libfolks_telepathy_la_VALASOURCES = \
	tpf-persona.vala \
	tpf-persona-store.vala \
	tpf-logger.vala \
	$(NULL)

libfolks_telepathy_la_SOURCES = \
	folks-telepathy.vala.stamp \
	$(libfolks_telepathy_la_VALASOURCES:.vala=.c) \
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

folks_telepathy_stamp_targets = \
	folks-telepathy.h \
	$(libfolks_telepathy_la_VALASOURCES:.vala=.c) \
	$(libfolks_telepathy_la_VALASOURCES:.vala=.h) \
	$(NULL)

$(folks_telepathy_stamp_targets): folks-telepathy.vala.stamp

folks_telepathy_vapi_deps = \
	$(libfolks_telepathy_la_VALASOURCES) \
	$(internal_vapi_files) \
	$(NULL)

folks-telepathy.vapi folks-telepathy.vala.stamp: $(folks_telepathy_vapi_deps)
	$(VALA_V)$(VALAC) $(VALACFLAGS) $(VALAFLAGS) -H folks-telepathy.h -C \
		--library folks-telepathy \
		--pkg tp-lowlevel \
		$(libfolks_telepathy_la_VALASOURCES)
	touch $@

##################################################################
# Backend
##################################################################

libfolks_backend_telepathy_la_VALASOURCES = \
	tp-backend.vala \
	tp-backend-factory.vala \
	$(NULL)

libfolks_backend_telepathy_la_SOURCES = \
	folks-backend-telepathy.vala.stamp \
	$(libfolks_backend_telepathy_la_VALASOURCES:.vala=.c) \
	$(NULL)

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

folks_backend_telepathy_stamp_targets = \
	folks-backend-telepathy.h \
	$(libfolks_backend_telepathy_la_VALASOURCES:.vala=.c) \
	$(libfolks_backend_telepathy_la_VALASOURCES:.vala=.h) \
	$(NULL)

$(folks_backend_telepathy_stamp_targets): folks-backend-telepathy.vala.stamp

vapi_deps = \
	folks-telepathy.vapi \
	libfolks-telepathy.la \
	$(libfolks_backend_telepathy_la_VALASOURCES) \
	$(internal_vapi_files) \
	$(NULL)

folks-backend-telepathy.vapi folks-backend-telepathy.vala.stamp: $(vapi_deps)
	$(VALA_V)$(VALAC) $(VALACFLAGS) $(VALAFLAGS) \
		-H folks-backend-telepathy.h -C \
		--library folks-backend-telepathy \
		--pkg folks \
		--pkg folks-telepathy \
		$(libfolks_backend_telepathy_la_VALASOURCES)
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
	$(libfolks_telepathy_la_VALASOURCES:.vala=.c) \
	$(libfolks_backend_telepathy_la_VALASOURCES:.vala=.c) \
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
	$(libfolks_telepathy_la_VALASOURCES:.vala=.c) \
	$(libfolks_backend_telepathy_la_VALASOURCES:.vala=.c) \
	$(NULL)

# set up the verbosity rules to avoid some build noise
# XXX: once automake >= 1.11 is common, remove these, push VALASOURCES files
# into SOURCES and add AM_PROG_VALAC to configure.ac
VALA_V = $(VALA_V_$(V))
VALA_V_ = $(VALA_V_$(AM_DEFAULT_VERBOSITY))
VALA_V_0 = @echo "  VALAC " $^;

VAPIGEN_V = $(VAPIGEN_V_$(V))
VAPIGEN_V_ = $(VAPIGEN_V_$(AM_DEFAULT_VERBOSITY))
VAPIGEN_V_0 = @echo "  VAPIG " $^;

VGI_V = $(VGI_V_$(V))
VGI_V_ = $(VGI_V_$(AM_DEFAULT_VERBOSITY))
VGI_V_0 = @echo "  VGI   " $^;
