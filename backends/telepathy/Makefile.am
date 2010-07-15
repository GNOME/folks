AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	$(NULL)

VALAFLAGS += $(TP_VALA_VALAFLAGS)
VALAFLAGS += --vapidir=. --vapidir=$(top_srcdir)/folks

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
	$(AM_V_GEN)$(VALA_GEN_INTROSPECT) --namespace=Folks \
		$(srcdir)/tp-lowlevel.h \
		$(GLIB_CFLAGS) $(DBUS_GLIB_CFLAGS) $(GEE_CFLAGS) \
		$(TP_VALA_CFLAGS) $(TP_GLIB_CFLAGS) -I$(top_srcdir)/folks \
		.libs/libtp-lowlevel.so > tp-lowlevel.gi

# copy the metadata file as necessary, to work around gnome bug #624278
tp-lowlevel.vapi: tp-lowlevel.gi tp-lowlevel.metadata
	test -e tp-lowlevel.metadata || \
		(cp $(srcdir)/tp-lowlevel.metadata . && \
		touch tp-lowlevel.metadata.copied)
	$(AM_V_GEN)$(VAPIGEN) $(TP_VALA_VALAFLAGS) --library tp-lowlevel \
		--metadata=tp-lowlevel.metadata --pkg gio-2.0 \
		--pkg telepathy-glib \
		tp-lowlevel.gi
	test ! -e tp-lowlevel.metadata.copied || rm -f tp-lowlevel.metadata*

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
# Backend
##################################################################

folks_backend_telepathy_valasources = \
	tp-backend.vala \
	tp-backend-factory.vala \
	$(NULL)

folks_backend_telepathy_deps = \
	folks \
	folks-telepathy \
	gee-1.0 \
	gio-2.0 \
	gobject-2.0 \
	telepathy-glib \
	$(NULL)

libfolks_backend_telepathy_la_SOURCES = \
	$(folks_backend_telepathy_valasources:.vala=.c)

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

folks-backend-telepathy.h $(libfolks_backend_telepathy_la_SOURCES): \
		folks-backend-telepathy.vala.stamp

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
		$(addprefix --pkg ,$(folks_backend_telepathy_deps)) \
		$(addprefix $(srcdir)/,$(folks_backend_telepathy_valasources))
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
	$(folks_telepathy_valasources) \
	$(folks_backend_telepathy_valasources) \
	$(libtp_lowlevel_la_SOURCES) \
	tp-lowlevel.metadata \
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
