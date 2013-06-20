BACKEND_NAME = "ofono"

backenddir = $(BACKEND_DIR)/ofono
backend_LTLIBRARIES = ofono.la

ofono_la_SOURCES = \
	ofono-backend.vala \
	ofono-backend-factory.vala \
	ofono-persona.vala \
	ofono-persona-store.vala \
	org-ofono.vala \
	$(NULL)

ofono_la_VALAFLAGS = \
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
	--pkg libebook-1.2 \
	--pkg libedataserver-1.2 \
	$(NULL)

# FIXME: libedataserver-1.2 doesn't need to be explicitly mentioned
# once we depend on libebook version that includes libedataserver-1.2
# in libebook-1.2.deps.

ofono_la_CPPFLAGS = \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

ofono_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(EBOOK_CFLAGS) \
	$(NULL)

ofono_la_LIBADD = \
	$(AM_LIBADD) \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(EBOOK_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(NULL)

ofono_la_LDFLAGS = \
	$(AM_LDFLAGS) \
	$(CODE_COVERAGE_LDFLAGS) \
	-shared \
	-fPIC \
	-module \
	-avoid-version \
	$(NULL)

-include $(top_srcdir)/git.mk
