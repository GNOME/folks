SUBDIRS = lib

BACKEND_NAME = "eds"

AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/eds/lib \
	-I$(top_srcdir)/backends/eds/lib/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

VALAFLAGS += \
	--vapidir=. \
	--vapidir=$(top_builddir)/backends/eds/lib \
	--vapidir=$(top_srcdir)/folks \
	$(addprefix --pkg ,$(eds_deps)) \
	$(NULL)

backenddir = $(BACKEND_DIR)/eds
backend_LTLIBRARIES = eds.la

eds_la_SOURCES = \
	eds-backend.vala \
	eds-backend-factory.vala \
	$(NULL)

eds_deps = \
	folks \
	folks-eds \
	gee-1.0 \
	gio-2.0 \
	gobject-2.0 \
	libebook-1.2 \
	libedataserver-1.2 \
	libxml-2.0 \
	$(NULL)

eds_la_CFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(EBOOK_CFLAGS) \
	$(EDATASERVER_CFLAGS) \
	$(LIBXML_CFLAGS) \
	$(NULL)

eds_la_LIBADD = \
	lib/libfolks-eds.la \
	$(top_builddir)/folks/libfolks.la \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(EBOOK_LIBS) \
	$(EDATASERVER_LIBS) \
	$(LIBXML_LIBS) \
	$(NULL)

eds_la_LDFLAGS = -shared -fPIC -module -avoid-version

GITIGNOREFILES = \
	folks-backend-eds.vapi \
	$(eds_la_SOURCES:.vala=.c) \
	eds_la_vala.stamp \
	$(NULL)

-include backend.mk
-include $(top_srcdir)/git.mk
