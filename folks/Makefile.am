GEN_INTROSPECT = $(shell pkg-config vala-1.0 --variable="gen_introspect")
VAPIGEN = $(shell pkg-config vala-1.0 --variable="vapigen")

AM_CPPFLAGS = \
	$(LIBFOLKS_CFLAGS) \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	$(NULL)

# this seems to work, even if vim's syntax highlighting suggests otherwise
VALAFLAGS += $(shell PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) pkg-config --variable=valaflags telepathy-vala)
VALAFLAGS += --vapidir=.
VALAFLAGS += --pkg gobject-2.0 --pkg gio-2.0 --pkg gee-1.0 --pkg dbus-glib-1 --pkg telepathy-glib

libfolksdir = $(includedir)/folks
lib_LTLIBRARIES = \
	liblowlevel.la \
	libfolks.la \
	$(NULL)

# FIXME: cut the redundancy here with lowlevel_sources, etc.
liblowlevel_la_SOURCES = \
	lowlevel.c \
	lowlevel.h \
	$(NULL)

liblowlevel_la_CPPFLAGS = \
	$(LIBLOWLEVEL_CFLAGS) \
	$(NULL)

liblowlevel_la_LDFLAGS = \
	$(LIBLOWLEVEL_LIBS) \
	$(NULL)

lowlevel_sources = \
	lowlevel.c \
	lowlevel.h \
	$(NULL)

# FIXME: wrap lines
# FIXME: use a better path to the .so file
lowlevel.gi: $(lowlevel_sources) liblowlevel.la
	$(VGI_V)$(GEN_INTROSPECT) --namespace=Folks lowlevel.h \
		$(shell pkg-config telepathy-glib --cflags) .libs/liblowlevel.so > lowlevel.gi

lowlevel.vapi: lowlevel.gi lowlevel.metadata
	$(VAPIGEN_V)$(VAPIGEN) $(VALAFLAGS) --library lowlevel \
		--metadata=lowlevel.metadata \
		lowlevel.gi

internal_vapi_files = \
	lowlevel.vapi \
	$(NULL)

libfolks_la_VALASOURCES = \
	alias.vala \
	capabilities.vala \
	groups.vala \
	individual.vala \
	individual-aggregator.vala \
	persona.vala \
	persona-store.vala \
	presence.vala \
	tp-persona.vala \
	tp-persona-store.vala \
	$(NULL)

libfolks_la_SOURCES = \
	folks.vala.stamp \
	$(libfolks_la_VALASOURCES:.vala=.c) \
	$(lowlevel_sources) \
	$(NULL)

libfolks_la_LIBADD = \
	$(LIBFOLKS_LIBS) \
	$(NULL)

folksdir = $(includedir)/folks

folks_HEADERS = \
	folks.h \
	$(NULL)

folks.h $(libfolks_la_VALASOURCES:.vala=.c) $(libfolks_la_VALASOURCES:.vala=.h): folks.vala.stamp

folks.vapi folks.vala.stamp: $(libfolks_la_VALASOURCES) $(internal_vapi_files)
	$(VALA_V)$(VALAC) $(VALAFLAGS) -C --pkg lowlevel -H folks.h --library folks $(libfolks_la_VALASOURCES)
	touch $@

pkgconfig_in = folks.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

BUILT_SOURCES = \
	folks.h \
	folks.vala.stamp \
	folks.vapi \
	lowlevel.gi \
	lowlevel.vapi \
	$(libfolks_la_VALASOURCES:.vala=.c) \
	$(pkgconfig_in:.in=) \
	$(NULL)

CLEANFILES = $(BUILT_SOURCES)

EXTRA_DIST = \
	$(pkgconfig_in) \
	folks.vala.stamp \
	folks.vapi \
	lowlevel.vapi \
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
