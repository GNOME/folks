GEN_INTROSPECT = $(shell pkg-config vala-1.0 --variable="gen_introspect")
VAPIGEN = $(shell pkg-config vala-1.0 --variable="vapigen")

AM_CPPFLAGS = \
	$(LIBTPP_CFLAGS) \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	$(NULL)

# this seems to work, even if vim's syntax highlighting suggests otherwise
VALAFLAGS += $(shell PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) pkg-config --variable=valaflags telepathy-vala)
VALAFLAGS += --vapidir=.
VALAFLAGS += --pkg gobject-2.0 --pkg gio-2.0 --pkg gee-1.0 --pkg dbus-glib-1 --pkg telepathy-glib

libtelepathy_peopledir = $(includedir)/telepathy-people
lib_LTLIBRARIES = \
	liblowlevel.la \
	libtelepathy-people.la \
	$(NULL)

# FIXME: cut the redundancy here with lowlevel_sources, etc.
liblowlevel_la_SOURCES = \
	lowlevel.c \
	lowlevel.h \
	$(NULL)

liblowlevel_la_CPPFLAGS = \
	$(LIBTPP_LOWLEVEL_CFLAGS) \
	$(NULL)

liblowlevel_la_LDFLAGS = \
	$(LIBTPP_LOWLEVEL_LIBS) \
	$(NULL)

lowlevel_sources = \
	lowlevel.c \
	lowlevel.h \
	$(NULL)

# FIXME: wrap lines
# FIXME: use a better path to the .so file
lowlevel.gi: $(lowlevel_sources) liblowlevel.la
	$(VGI_V)$(GEN_INTROSPECT) --namespace=Tpp lowlevel.h \
		$(shell pkg-config telepathy-glib --cflags) .libs/liblowlevel.so > lowlevel.gi

lowlevel.vapi: lowlevel.gi
	$(VAPIGEN_V)$(VAPIGEN) $(VALAFLAGS) --library lowlevel lowlevel.gi

internal_vapi_files = \
	lowlevel.vapi \
	$(NULL)

libtelepathy_people_la_VALASOURCES = \
	alias.vala \
	individual.vala \
	individual-aggregator.vala \
	persona.vala \
	persona-store.vala \
	tp-persona.vala \
	$(NULL)

libtelepathy_people_la_SOURCES = \
	telepathy-people.vala.stamp \
	$(libtelepathy_people_la_VALASOURCES:.vala=.c) \
	$(lowlevel_sources) \
	$(NULL)

libtelepathy_people_la_LIBADD = \
	$(LIBTPP_LIBS) \
	$(NULL)

telepathy_peopledir = $(includedir)/telepathy-people

telepathy_people_HEADERS = \
	telepathy-people.h \
	$(NULL)

telepathy-people.h $(libtelepathy_people_la_VALASOURCES:.vala=.c) $(libtelepathy_people_la_VALASOURCES:.vala=.h): telepathy-people.vala.stamp

telepathy-people.vapi telepathy-people.vala.stamp: $(libtelepathy_people_la_VALASOURCES) $(internal_vapi_files)
	$(VALA_V)$(VALAC) $(VALAFLAGS) -C --pkg lowlevel -H telepathy-people.h --library telepathy-people $(libtelepathy_people_la_VALASOURCES)
	touch $@

pkgconfig_in = telepathy-people.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

BUILT_SOURCES = \
	telepathy-people.h \
	telepathy-people.vala.stamp \
	telepathy-people.vapi \
	lowlevel.gi \
	lowlevel.vapi \
	$(libtelepathy_people_la_VALASOURCES:.vala=.c) \
	$(pkgconfig_in:.in=) \
	$(NULL)

CLEANFILES = $(BUILT_SOURCES)

EXTRA_DIST = \
	$(pkgconfig_in) \
	telepathy-people.vala.stamp \
	telepathy-people.vapi \
	lowlevel.vapi \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(libtelepathy_people_la_VALASOURCES:.vala=.c) \
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
