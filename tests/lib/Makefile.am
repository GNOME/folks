SUBDIRS = \
	key-file \
	telepathy \
	$(NULL)

if ENABLE_TRACKER
SUBDIRS += tracker
endif

DIST_SUBDIRS = \
	key-file \
	telepathy \
	$(NULL)

if ENABLE_TRACKER
DIST_SUBDIRS += tracker
endif

noinst_LTLIBRARIES = libfolks-test.la

libfolks_test_la_SOURCES = test-case.vala
libfolks_test_la_CFLAGS = $(GLIB_CFLAGS)
libfolks_test_la_LIBADD = $(GLIB_LIBS)

libfolks_test_la_VALAFLAGS = \
	$(VALAFLAGS) \
	--pkg gobject-2.0 \
	--library folks-test \
	-H folks-test.h \
	$(NULL)

CLEANFILES = \
	folks-test-uninstalled.pc \
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
