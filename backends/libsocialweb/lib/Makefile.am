CLEANFILES =
MAINTAINERCLEANFILES =
EXTRA_DIST =

include $(top_srcdir)/backends/backend-library.mk

BACKEND_NAME = libsocialweb
BACKEND_NAME_C = Libsocialweb
BACKEND_LT_VERSION = $(FOLKS_LIBSOCIALWEB_LT_VERSION)
BACKEND_API_VERSION = $(FOLKS_LIBSOCIALWEB_API_VERSION)
BACKEND_SYMBOLS_REGEX = "^swf_.*"
BACKEND_NAMESPACE = Swf

lib_LTLIBRARIES = libfolks-libsocialweb.la

libfolks_libsocialweb_la_SOURCES = \
	$(backend_library_sources) \
	swf-persona.vala \
	swf-persona-store.vala \
	$(NULL)

libfolks_libsocialweb_la_VALAFLAGS = \
	$(backend_library_valaflags) \
	--pkg libsocialweb-client \
	$(NULL)

libfolks_libsocialweb_la_CPPFLAGS = \
	$(backend_library_cppflags) \
	$(NULL)

libfolks_libsocialweb_la_CFLAGS = \
	$(backend_library_cflags) \
	$(SW_CLIENT_CFLAGS) \
	$(NULL)

libfolks_libsocialweb_la_LIBADD = \
	$(backend_library_LIBADD) \
	$(SW_CLIENT_LIBS) \
	$(NULL)

libfolks_libsocialweb_la_LDFLAGS = \
	$(backend_library_ldflags) \
	$(NULL)


-include $(top_srcdir)/git.mk
