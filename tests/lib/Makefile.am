SUBDIRS = \
	key-file \
	telepathy \
	$(NULL)

if ENABLE_LIBSOCIALWEB
SUBDIRS += libsocialweb
endif

if ENABLE_TRACKER
SUBDIRS += tracker
endif

if ENABLE_EDS
SUBDIRS += eds
endif

DIST_SUBDIRS = \
	key-file \
	telepathy \
	libsocialweb \
	tracker \
	eds \
	$(NULL)

noinst_LTLIBRARIES = libfolks-test.la

libfolks_test_la_SOURCES = test-case.vala test-utils.vala
libfolks_test_la_CFLAGS = $(GLIB_CFLAGS) $(GIO_CFLAGS)
libfolks_test_la_LIBADD = $(GLIB_LIBS) $(GIO_LIBS)

libfolks_test_la_VALAFLAGS = \
	$(ERROR_VALAFLAGS) \
	$(VALAFLAGS) \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--library folks-test \
	-H folks-test.h \
	-g \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(libfolks_test_la_SOURCES:.vala=.c) \
	libfolks_test_la_vala.stamp \
	folks-test.h \
	folks-test.vapi \
	$(NULL)

EXTRA_DIST = \
	$(MAINTAINERCLEANFILES) \
	$(NULL)

-include $(top_srcdir)/git.mk
