BACKEND_NAME = "key-file"

backenddir = $(BACKEND_DIR)/key-file
backend_LTLIBRARIES = key-file.la

key_file_la_SOURCES = \
	kf-backend.vala \
	kf-backend-factory.vala \
	kf-persona.vala \
	kf-persona-store.vala \
	$(NULL)

key_file_la_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--pkg folks \
	--pkg folks-generics \
	--pkg folks-internal \
	--pkg gee-0.8 \
	--pkg gio-2.0 \
	--pkg gobject-2.0 \
	$(NULL)

key_file_la_CPPFLAGS = \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

key_file_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

key_file_la_LIBADD = \
	$(AM_LIBADD) \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(NULL)

key_file_la_LDFLAGS = \
	$(AM_LDFLAGS) \
	$(CODE_COVERAGE_LDFLAGS) \
	-shared \
	-fPIC \
	-module \
	-avoid-version \
	$(NULL)

-include $(top_srcdir)/git.mk
