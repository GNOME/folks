SUBDIRS = lib .

include $(top_srcdir)/backends/backend.mk
BACKEND_NAME = "libsocialweb"

backenddir = $(BACKEND_DIR)/libsocialweb
backend_LTLIBRARIES = libsocialweb.la

libsocialweb_la_VALAFLAGS = \
	$(backend_valaflags) \
	--vapidir=$(top_builddir)/backends/libsocialweb/lib \
	--pkg folks-libsocialweb \
	--pkg libsocialweb-client \
	$(NULL)

libsocialweb_la_SOURCES = \
	$(backend_sources) \
	sw-backend.vala \
	sw-backend-factory.vala \
	$(NULL)

libsocialweb_la_CPPFLAGS = \
	$(backend_cppflags) \
	-I$(top_srcdir)/backends/libsocialweb/lib \
	-I$(top_srcdir)/backends/libsocialweb/lib/folks \
	$(NULL)

libsocialweb_la_CFLAGS = \
	$(backend_cflags) \
	$(SW_CLIENT_CFLAGS) \
	$(NULL)

libsocialweb_la_LIBADD = \
	$(backend_libadd) \
	$(top_builddir)/backends/libsocialweb/lib/libfolks-libsocialweb.la \
	$(SW_CLIENT_LIBS) \
	$(NULL)

libsocialweb_la_LDFLAGS = \
	-module -avoid-version \
	$(backend_ldflags) \
	$(NULL)

-include $(top_srcdir)/git.mk
