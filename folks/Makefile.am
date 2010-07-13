sharedir = $(datadir)/folks
backenddir = $(libdir)/folks

AM_CPPFLAGS = \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DDATA_DIR=\"$(shareddir)\" \
	-DBACKEND_DIR=\"$(backenddir)\" \
	$(NULL)

# this seems to work, even if vim's syntax highlighting suggests otherwise
VALAFLAGS += $(shell PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) pkg-config --variable=valaflags telepathy-vala)
VALAFLAGS += --vapidir=.
VALAFLAGS += --pkg build-conf --pkg gobject-2.0 --pkg gio-2.0 --pkg gee-1.0 \
		--pkg gmodule-2.0 --pkg dbus-glib-1 --pkg telepathy-glib

libfolksdir = $(includedir)/folks
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
	$(VALA_V)$(VALAC) $(VALACFLAGS) $(VALAFLAGS) -C -H folks.h \
		--library folks \
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
	$(libfolks_la_VALASOURCES) \
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

VAPIGEN_V = $(VAPIGEN_V_$(V))
VAPIGEN_V_ = $(VAPIGEN_V_$(AM_DEFAULT_VERBOSITY))
VAPIGEN_V_0 = @echo "  VAPIG " $^;

VGI_V = $(VGI_V_$(V))
VGI_V_ = $(VGI_V_$(AM_DEFAULT_VERBOSITY))
VGI_V_0 = @echo "  VGI   " $^;
