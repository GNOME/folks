SUBDIRS = lib

BACKEND_NAME = "libsocialweb"

AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/libsocialweb/lib \
	-I$(top_srcdir)/backends/libsocialweb/lib/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

VALAFLAGS += \
	--vapidir=. \
	--vapidir=$(top_builddir)/backends/libsocialweb/lib \
	--vapidir=$(top_srcdir)/folks \
	$(addprefix --pkg ,$(folks_backend_libsocialweb_deps)) \
	$(NULL)

backenddir = $(BACKEND_DIR)/libsocialweb
backend_LTLIBRARIES = libfolks-backend-libsocialweb.la

libfolks_backend_libsocialweb_la_SOURCES = \
	sw-backend.vala \
	sw-backend-factory.vala \
	$(NULL)

folks_backend_libsocialweb_deps = \
	folks \
        folks-libsocialweb \
	gee-1.0 \
	gio-2.0 \
	gobject-2.0 \
	libsocialweb-client \
	$(NULL)

libfolks_backend_libsocialweb_la_CFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(SW_CLIENT_CFLAGS) \
	$(NULL)

libfolks_backend_libsocialweb_la_LIBADD = \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(SW_CLIENT_LIBS) \
	lib/libfolks-libsocialweb.la \
	$(NULL)

libfolks_backend_libsocialweb_la_LDFLAGS = -shared -fPIC -module -avoid-version

GITIGNOREFILES = \
	folks-backend-libsocialweb.vapi \
	$(libfolks_backend_libsocialweb_la_SOURCES:.vala=.c) \
	libfolks_backend_libsocialweb_la_vala.stamp \
	$(NULL)

-include $(top_srcdir)/git.mk
