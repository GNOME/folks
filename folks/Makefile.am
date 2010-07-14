sharedir = $(datadir)/folks
backenddir = $(libdir)/folks

AM_CPPFLAGS = \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DDATA_DIR=\"$(shareddir)\" \
	-DBACKEND_DIR=\"$(backenddir)\" \
	$(NULL)

# Build-time dependencies for libfolks
folks_deps = \
	build-conf \
	gobject-2.0 \
	gmodule-2.0 \
	gio-2.0 \
	gee-1.0 \
	$(NULL)

lib_LTLIBRARIES = \
	libfolks.la \
	$(NULL)

libfolks_la_VALASOURCES = \
	alias.vala \
	avatar.vala \
	backend.vala \
	backend-store.vala \
	favourite.vala \
	groups.vala \
	individual.vala \
	individual-aggregator.vala \
	persona.vala \
	persona-store.vala \
	presence.vala \
	$(NULL)

libfolks_la_SOURCES = \
	folks.vala.stamp \
	$(libfolks_la_VALASOURCES:.vala=.c) \
	$(NULL)

libfolks_la_CFLAGS = \
	$(GLIB_CFLAGS) \
	$(DBUS_GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_VALA_CFLAGS) \
	$(NULL)

libfolks_la_LIBADD = \
	$(GLIB_LIBS) \
	$(DBUS_GLIB_LIBS) \
	$(GEE_LIBS) \
	$(TP_VALA_LIBS) \
	$(NULL)

folksdir = $(includedir)/folks

folks_HEADERS = \
	folks.h \
	$(NULL)

folks.h $(libfolks_la_VALASOURCES:.vala=.c) $(libfolks_la_VALASOURCES:.vala=.h): folks.vala.stamp

folks.vapi folks.vala.stamp: $(libfolks_la_VALASOURCES)
	$(VALA_V)$(VALAC) $(VALACFLAGS) $(TP_VALA_VALAFLAGS) -C -H folks.h \
		--library folks --vapidir=. $(addprefix --pkg ,$(folks_deps)) \
		$(libfolks_la_VALASOURCES)
	touch $@

pkgconfig_in = folks.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

BUILT_SOURCES = \
	folks.h \
	folks.vala.stamp \
	folks.vapi \
	$(libfolks_la_VALASOURCES:.vala=.c) \
	$(pkgconfig_in:.in=) \
	folks-uninstalled.pc \
	$(NULL)

CLEANFILES = $(BUILT_SOURCES)

EXTRA_DIST = \
	$(pkgconfig_in) \
	build-conf.vapi \
	folks.vala.stamp \
	folks.vapi \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(libfolks_la_VALASOURCES:.vala=.c) \
	$(NULL)

# set up the verbosity rules to avoid some build noise
# XXX: once automake >= 1.11 is common, remove these, push VALASOURCES files
# into SOURCES and add AM_PROG_VALAC to configure.ac
VALA_V = $(VALA_V_$(V))
VALA_V_ = $(VALA_V_$(AM_DEFAULT_VERBOSITY))
VALA_V_0 = @echo "  VALAC " $^;

-include $(top_srcdir)/git.mk
