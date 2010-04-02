AM_CPPFLAGS = \
	$(LIBTPP_CFLAGS) \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	$(NULL)

BUILT_SOURCES = telepathy-people.vala.stamp

LIBTPLdir = $(includedir)/telepathy-people
lib_LTLIBRARIES = libtelepathy-people.la

libtelepathy_people_la_VALASOURCES = \
	persona-store.vala \
	$(NULL)

libtelepathy_people_la_SOURCES = \
	$(libtelepathy_people_la_VALASOURCES:.vala=.c) \
	$(NULL)

libtelepathy_people_la_LIBADD = \
	$(LIBTPP_LIBS) \
	$(NULL)

telepathy_peopleincludedir = $(includedir)/telepathy-people

telepathy_peopleinclude_HEADERS = \
	telepathy-people.h \
	$(NULL)

telepathy-people.vapi telepathy-people.vala.stamp: $(libtelepathy_people_la_VALASOURCES)
	$(VALAC) $(VALAFLAGS) -C --pkg gobject-2.0 -H telepathy-people.h --library telepathy-people $^
	touch $@

EXTRA_DIST = \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(libtelepathy_people_la_VALASOURCES:.vala=.c) \
	$(NULL)
