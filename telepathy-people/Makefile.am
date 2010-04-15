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
	libtp-lowlevel.la \
	libtelepathy-people.la \
	$(NULL)

# FIXME: cut the redundancy here with tp_lowlevel_sources, etc.
libtp_lowlevel_la_SOURCES = \
	tp-lowlevel.c \
	tp-lowlevel.h \
	$(NULL)

libtp_lowlevel_la_CPPFLAGS = \
	$(LIBTP_LOWLEVEL_CFLAGS) \
	$(NULL)

libtp_lowlevel_la_LDFLAGS = \
	$(LIBTP_LOWLEVEL_LIBS) \
	$(NULL)

tp_lowlevel_sources = \
	tp-lowlevel.c \
	tp-lowlevel.h \
	$(NULL)

# FIXME: wrap lines
# FIXME: use a better path to the .so file
tp-lowlevel.gi: $(tp_lowlevel_sources) libtp-lowlevel.la
	$(GEN_INTROSPECT) --namespace=Tp tp-lowlevel.h \
		$(shell pkg-config telepathy-glib --cflags) .libs/libtp-lowlevel.so > tp-lowlevel.gi

tp-lowlevel.vapi: tp-lowlevel.gi
	$(VAPIGEN) $(VALAFLAGS) --library tp-lowlevel tp-lowlevel.gi

internal_vapi_files = \
	tp-lowlevel.vapi \
	$(NULL)

libtelepathy_people_la_VALASOURCES = \
	individual.vala \
	individual-aggregator.vala \
	persona-store.vala \
	$(NULL)

libtelepathy_people_la_SOURCES = \
	telepathy-people.vala.stamp \
	$(libtelepathy_people_la_VALASOURCES:.vala=.c) \
	$(tp_lowlevel_sources) \
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
	$(VALAC) $(VALAFLAGS) -C --pkg tp-lowlevel -H telepathy-people.h --library telepathy-people $(libtelepathy_people_la_VALASOURCES)
	touch $@

pkgconfig_in = telepathy-people.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

BUILT_SOURCES = \
	telepathy-people.vala.stamp \
	telepathy-people.h \
	tp-lowlevel.gi \
	tp-lowlevel.vapi \
	$(libtelepathy_people_la_VALASOURCES:.vala=.c) \
	$(pkgconfig_in:.in=) \
	$(NULL)

CLEANFILES = $(BUILT_SOURCES)

EXTRA_DIST = \
	$(pkgconfig_in) \
	telepathy-people.vala.stamp \
	telepathy-people.vapi \
	tp-lowlevel.vapi \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(libtelepathy_people_la_VALASOURCES:.vala=.c) \
	$(NULL)
