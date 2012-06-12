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
# comment out eds tests until they are ported to eds api changes.
# https://bugzilla.gnome.org/show_bug.cgi?id=675121
#SUBDIRS += eds
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

libfolks_test_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

libfolks_test_la_CPPFLAGS = \
	$(AM_CPPFLAGS) \
	-I$(top_srcdir)/folks \
	$(NULL)

libfolks_test_la_LIBADD = \
	$(AM_LIBADD) \
	$(top_builddir)/folks/libfolks.la \
	$(GLIB_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

libfolks_test_la_VALAFLAGS = \
	$(ERROR_VALAFLAGS) \
	$(VALAFLAGS) \
	--vapidir=$(top_srcdir)/folks \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--pkg folks \
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
