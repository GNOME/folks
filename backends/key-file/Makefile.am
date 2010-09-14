AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DG_LOG_DOMAIN=\"KeyFileBackend\" \
	$(NULL)

VALAFLAGS += \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	$(addprefix --pkg ,$(folks_backend_key_file_deps)) \
	$(NULL)

backenddir = $(BACKEND_DIR)/key-file
backend_LTLIBRARIES = libfolks-backend-key-file.la

libfolks_backend_key_file_la_SOURCES = \
	kf-backend.vala \
	kf-backend-factory.vala \
	kf-persona.vala \
	kf-persona-store.vala \
	$(NULL)

folks_backend_key_file_deps = \
	folks \
	gee-1.0 \
	gio-2.0 \
	gobject-2.0 \
	$(NULL)

libfolks_backend_key_file_la_CFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

libfolks_backend_key_file_la_LIBADD = \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(NULL)

libfolks_backend_key_file_la_LDFLAGS = -shared -fPIC -module -avoid-version

GITIGNOREFILES = \
	folks-backend-key-file.vapi \
	$(libfolks_backend_key_file_la_SOURCES:.vala=.c) \
	libfolks_backend_key_file_la_vala.stamp \
	$(NULL)

-include $(top_srcdir)/git.mk
