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

libfolks_backend_key_file_la_CPPFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(AM_CPPFLAGS) \
	$(NULL)

libfolks_backend_key_file_la_LIBADD = \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

libfolks_backend_key_file_la_LDFLAGS = -shared -fPIC -module -avoid-version

-include $(top_srcdir)/git.mk
