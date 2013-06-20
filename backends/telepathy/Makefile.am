SUBDIRS = lib

BACKEND_NAME = "telepathy"

telepathy_la_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--vapidir=$(abs_srcdir) \
	--vapidir=$(abs_builddir) \
	--vapidir=$(abs_top_srcdir)/backends/telepathy/lib \
	--vapidir=$(abs_top_builddir)/backends/telepathy/lib \
	--vapidir=$(abs_top_srcdir)/folks \
	--vapidir=$(abs_top_builddir)/folks \
	--pkg folks \
	--pkg folks-internal \
	--pkg folks-telepathy \
	--pkg gee-0.8 \
	--pkg gio-2.0 \
	--pkg gobject-2.0 \
	--pkg telepathy-glib \
	$(NULL)

backenddir = $(BACKEND_DIR)/telepathy
backend_LTLIBRARIES = telepathy.la

telepathy_la_SOURCES = \
	tp-backend.vala \
	tp-backend-factory.vala \
	$(NULL)

telepathy_la_CPPFLAGS = \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/telepathy/lib \
	-I$(top_srcdir)/backends/telepathy/lib/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

telepathy_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	$(NULL)

telepathy_la_LIBADD = \
	$(AM_LIBADD) \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(TP_GLIB_LIBS) \
	lib/libfolks-telepathy.la \
	$(NULL)

telepathy_la_LDFLAGS = \
	$(AM_LDFLAGS) \
	$(CODE_COVERAGE_LDFLAGS) \
	-shared \
	-fPIC \
	-module \
	-avoid-version \
	$(NULL)

-include $(top_srcdir)/git.mk
