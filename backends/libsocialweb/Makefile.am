SUBDIRS = lib

BACKEND_NAME = "libsocialweb"

libsocialweb_la_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--vapidir=. \
	--vapidir=$(top_builddir)/backends/libsocialweb/lib \
	--vapidir=$(top_srcdir)/folks \
	--pkg folks \
	--pkg folks-internal \
	--pkg folks-libsocialweb \
	--pkg gee-0.8 \
	--pkg gio-2.0 \
	--pkg gobject-2.0 \
	--pkg libsocialweb-client \
	$(NULL)

backenddir = $(BACKEND_DIR)/libsocialweb
backend_LTLIBRARIES = libsocialweb.la

libsocialweb_la_SOURCES = \
	sw-backend.vala \
	sw-backend-factory.vala \
	$(NULL)

libsocialweb_la_CPPFLAGS = \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/libsocialweb/lib \
	-I$(top_srcdir)/backends/libsocialweb/lib/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

libsocialweb_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(SW_CLIENT_CFLAGS) \
	$(NULL)

libsocialweb_la_LIBADD = \
	$(AM_LIBADD) \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(SW_CLIENT_LIBS) \
	lib/libfolks-libsocialweb.la \
	$(NULL)

libsocialweb_la_LDFLAGS = \
	$(AM_LDFLAGS) \
	$(CODE_COVERAGE_LDFLAGS) \
	-shared \
	-fPIC \
	-module \
	-avoid-version \
	$(NULL)

-include $(top_srcdir)/git.mk
