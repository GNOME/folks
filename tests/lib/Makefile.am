SUBDIRS = \
	key-file \
	telepathy \
	$(NULL)

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
	$(libfolks_test_la_SOURCES:.vala=.c) \
	*.stamp \
	folks-test.h \
	folks-test.vapi \
	folks-test-uninstalled.pc \
	$(NULL)

-include $(top_srcdir)/git.mk
