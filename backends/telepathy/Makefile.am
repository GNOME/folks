SUBDIRS = lib

BACKEND_NAME = "telepathy"

AM_VALAFLAGS += \
	$(ERROR_VALAFLAGS) \
	--vapidir=$(abs_srcdir) \
	--vapidir=$(abs_builddir) \
	--vapidir=$(abs_top_srcdir)/backends/telepathy/lib \
	--vapidir=$(abs_top_builddir)/backends/telepathy/lib \
	--vapidir=$(abs_top_srcdir)/folks \
	--vapidir=$(abs_top_builddir)/folks \
	$(addprefix --pkg ,$(telepathy_deps)) \
	$(NULL)

backenddir = $(BACKEND_DIR)/telepathy
backend_LTLIBRARIES = telepathy.la

telepathy_la_SOURCES = \
	tp-backend.vala \
	tp-backend-factory.vala \
	$(NULL)

telepathy_deps = \
	folks \
	folks-internal \
	folks-telepathy \
	gee-0.8 \
	gio-2.0 \
	gobject-2.0 \
	telepathy-glib \
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

GITIGNOREFILES = \
	folks-backend-telepathy.vapi \
	$(patsubst %.vala,%.c,$(filter %.vala,$(telepathy_la_SOURCES))) \
	telepathy_la_vala.stamp \
	$(NULL)

-include $(top_srcdir)/git.mk
