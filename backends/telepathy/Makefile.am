SUBDIRS = lib

AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/telepathy/lib \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

VALAFLAGS += \
	--vapidir=. \
	--vapidir=$(top_builddir)/backends/telepathy/lib \
	--vapidir=$(top_srcdir)/folks \
	$(addprefix --pkg ,$(folks_backend_telepathy_deps)) \
	$(NULL)

backenddir = $(BACKEND_DIR)/telepathy
backend_LTLIBRARIES = libfolks-backend-telepathy.la

libfolks_backend_telepathy_la_SOURCES = \
	tp-backend.vala \
	tp-backend-factory.vala \
	$(NULL)

folks_backend_telepathy_deps = \
	folks \
	folks-telepathy \
	gee-1.0 \
	gio-2.0 \
	gobject-2.0 \
	telepathy-glib \
	$(NULL)

libfolks_backend_telepathy_la_CFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	$(NULL)

libfolks_backend_telepathy_la_LIBADD = \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(TP_GLIB_LIBS) \
	lib/libfolks-telepathy.la \
	$(NULL)

libfolks_backend_telepathy_la_LDFLAGS = -shared -fPIC -module -avoid-version

GITIGNOREFILES = \
	folks-backend-telepathy.vapi \
	$(libfolks_backend_telepathy_la_SOURCES:.vala=.c) \
	libfolks_backend_telepathy_la_vala.stamp \
	$(NULL)

-include backend.mk
-include $(top_srcdir)/git.mk
