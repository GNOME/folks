SUBDIRS = lib

AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/telepathy/lib \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DG_LOG_DOMAIN=\"TelepathyBackend\" \
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

libfolks_backend_telepathy_la_CPPFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(DBUS_GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	$(AM_CPPFLAGS) \
	$(NULL)

libfolks_backend_telepathy_la_LIBADD = \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(DBUS_GLIB_LIBS) \
	$(GEE_LIBS) \
	$(TP_GLIB_LIBS) \
	lib/libfolks-telepathy.la \
	$(NULL)

libfolks_backend_telepathy_la_LDFLAGS = -shared -fPIC -module -avoid-version

-include $(top_srcdir)/git.mk
