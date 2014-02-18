noinst_LTLIBRARIES = libkf-test.la

libkf_test_la_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	$(TARGET_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--library kf-test \
	--vapi kf-test.vapi \
	--header kf-test.h \
	--vapidir=$(abs_srcdir) \
	--vapidir=$(abs_builddir) \
	--vapidir=$(abs_top_srcdir)/folks \
	--vapidir=$(abs_top_builddir)/folks \
	--vapidir=$(abs_top_srcdir)/tests/lib \
	--vapidir=$(abs_top_builddir)/tests/lib \
	--pkg folks-test \
	--pkg folks-test-dbus \
	-g \
	$(NULL)

libkf_test_la_SOURCES = \
	backend.vala \
	test-case.vala \
	$(NULL)

libkf_test_la_CPPFLAGS = \
	$(AM_CPPFLAGS) \
	-include $(top_srcdir)/folks/warnings.h \
	$(NULL)

libkf_test_la_CFLAGS = \
	-I$(top_srcdir) \
	-I$(top_srcdir)/tests/lib \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

libkf_test_la_LIBADD = \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

EXTRA_DIST = \
	kf-test.deps \
	kf-test.vapi \
	kf-test.h \
	$(NULL)

-include $(top_srcdir)/git.mk
