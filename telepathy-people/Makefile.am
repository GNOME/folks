AM_CPPFLAGS = \
	$(LIBTPP_CFLAGS) \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	$(NULL)

libtelepathy_peopledir = $(includedir)/telepathy-people
lib_LTLIBRARIES = libtelepathy-people.la

libtelepathy_people_la_VALASOURCES = \
	individual.vala \
	individual-aggregator.vala \
	persona-store.vala \
	$(NULL)

libtelepathy_people_la_SOURCES = \
	telepathy-people.vala.stamp \
	$(libtelepathy_people_la_VALASOURCES:.vala=.c) \
	$(NULL)

libtelepathy_people_la_LIBADD = \
	$(LIBTPP_LIBS) \
	$(NULL)

telepathy_peopledir = $(includedir)/telepathy-people

telepathy_people_HEADERS = \
	telepathy-people.h \
	$(NULL)

# this seems to work, even if vim's syntax highlighting suggests otherwise
VALAFLAGS += $(shell PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) pkg-config --variable=valaflags telepathy-vala)

telepathy-people.h $(libtelepathy_people_la_VALASOURCES:.vala=.c) $(libtelepathy_people_la_VALASOURCES:.vala=.h): telepathy-people.vala.stamp

telepathy-people.vapi telepathy-people.vala.stamp: $(libtelepathy_people_la_VALASOURCES)
	$(VALAC) $(VALAFLAGS) -C --pkg gobject-2.0 --pkg gio-2.0 --pkg dbus-glib-1 --pkg telepathy-glib -H telepathy-people.h --library telepathy-people $^
	touch $@

pkgconfig_in = telepathy-people.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

BUILT_SOURCES = \
	telepathy-people.vala.stamp \
	telepathy-people.h \
	$(libtelepathy_people_la_VALASOURCES:.vala=.c) \
	$(pkgconfig_in:.in=) \
	$(NULL)

CLEANFILES = $(BUILT_SOURCES)

EXTRA_DIST = \
	$(pkgconfig_in) \
	telepathy-people.vala.stamp \
	telepathy-people.vapi \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(libtelepathy_people_la_VALASOURCES:.vala=.c) \
	$(NULL)
