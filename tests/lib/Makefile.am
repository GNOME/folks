SUBDIRS = \
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

# The quoting here is unnecessary but harmless, and has the useful side-effect
# that vim quickfix mode (:make) doesn't interpret the libtool --mode=link
# command as an error message in a bizarrely named file
libfolks_test_la_LDFLAGS = \
        -version-info "$(LT_CURRENT)":"$(LT_REVISION)":"$(LT_AGE)"

CLEANFILES = \
	$(libfolks_test_la_SOURCES:.vala=.c) \
	*.stamp \
	folks-test.h \
	folks-test.vapi \
	folks-test-uninstalled.pc \
	$(NULL)

-include $(top_srcdir)/git.mk
