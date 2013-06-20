noinst_LTLIBRARIES = libsocialweb-test.la

libsocialweb_test_la_VALAFLAGS = \
	$(ERROR_VALAFLAGS) \
	$(AM_VALAFLAGS) \
	--library libsocialweb-test \
	--vapi libsocialweb-test.vapi \
	--header libsocialweb-test.h \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/libsocialweb/lib \
	--vapidir=$(abs_top_srcdir)/tests/lib \
	--vapidir=$(abs_top_builddir)/tests/lib \
	--vapidir=. \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg folks \
	--pkg libsocialweb-client \
	--pkg folks-libsocialweb \
	--pkg folks-test \
	-g \
	$(NULL)

libsocialweb_test_la_SOURCES = \
	backend.vala \
	test-case.vala \
	$(NULL)

libsocialweb_test_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	-I$(top_srcdir) \
	-I$(top_srcdir)/backends/libsocialweb/lib \
	-I$(top_srcdir)/tests/lib \
	$(NULL)

libsocialweb_test_la_LIBADD = \
	$(GLIB_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(top_builddir)/backends/libsocialweb/lib/libfolks-libsocialweb.la \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(NULL)

EXTRA_DIST = \
	libsocialweb-test.vapi \
	libsocialweb-test.h \
	$(NULL)

-include $(top_srcdir)/git.mk
