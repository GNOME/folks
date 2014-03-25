noinst_LTLIBRARIES = libdummy-test.la

libdummy_test_la_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--library dummy-test \
	--vapi dummy-test.vapi \
	--header dummy-test.h \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/dummy/lib \
	--vapidir=$(top_srcdir)/backends/dummy/vapi \
	--vapidir=$(abs_top_srcdir)/tests/lib \
	--vapidir=$(abs_top_builddir)/tests/lib \
	--vapidir=. \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg folks \
	--pkg folks-dummy \
	--pkg folks-test \
	--pkg folks-test-dbus \
	-g \
	$(NULL)

libdummy_test_la_SOURCES = \
	test-case.vala \
	$(NULL)

libdummy_test_la_CPPFLAGS = \
	$(AM_CPPFLAGS) \
	-include $(top_srcdir)/folks/warnings.h \
	$(NULL)

libdummy_test_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/tests/lib \
	-I$(top_srcdir)/backends/dummy/lib \
	-I$(top_srcdir)/backends/dummy/lib/folks \
	-I$(top_srcdir)/tests/lib \
	$(NULL)

libdummy_test_la_LIBADD = \
	$(top_builddir)/folks/libfolks.la \
	$(top_builddir)/backends/dummy/lib/libfolks-dummy.la \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

EXTRA_DIST = \
	dummy-test.vapi \
	dummy-test.h \
	$(NULL)

-include $(top_srcdir)/git.mk
