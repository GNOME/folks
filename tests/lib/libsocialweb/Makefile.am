VALAFLAGS += \
	--library=libsocialweb-test \
	--header=libsocialweb-test.h \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/libsocialweb/lib \
	--vapidir=. \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--pkg folks \
	--pkg libsocialweb-client \
	--pkg folks-libsocialweb \
	-g \
	$(NULL)

noinst_LTLIBRARIES = libsocialweb-test.la

libsocialweb_test_la_SOURCES = \
	backend.vala \
	$(NULL)

libsocialweb_test_la_CFLAGS = \
	$(GLIB_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	-I$(top_srcdir)/backends/libsocialweb/lib \
	$(NULL)

libsocialweb_test_la_LIBADD = \
	$(GLIB_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(top_builddir)/backends/libsocialweb/lib/libfolks-libsocialweb.la \
	$(NULL)

MAINTAINERCLEANFILES = \
	libsocialweb-test.vapi \
	libsocialweb-test.h \
	$(NULL)

DISTCLEANFILES = \
	session.conf \
	$(NULL)

EXTRA_DIST = \
	libsocialweb-test.vapi \
	libsocialweb-test.h \
	session.conf.in \
	$(NULL)

GITIGNOREFILES = \
	$(libsocialweb_test_la_SOURCES:.vala=.c) \
	libsocialweb_test_la_vala.stamp \
	$(NULL)

-include $(top_srcdir)/git.mk
