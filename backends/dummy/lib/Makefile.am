CLEANFILES =
MAINTAINERCLEANFILES =
EXTRA_DIST =

include $(top_srcdir)/backends/backend-library.mk

BACKEND_NAME = dummy
BACKEND_NAME_C = Dummy
BACKEND_LT_VERSION = $(FOLKS_DUMMY_LT_VERSION)
BACKEND_API_VERSION = $(FOLKS_DUMMY_API_VERSION)
BACKEND_SYMBOLS_REGEX = "^(FOLKS_DUMMY|folks_dummy)_.*|"
BACKEND_NAMESPACE = Dummy

lib_LTLIBRARIES = libfolks-dummy.la

# Deliberately don't include $(backend_library_sources) to avoid namespace.vala
libfolks_dummy_la_SOURCES = \
	dummy-backend.vala \
	dummy-persona.vala \
	dummy-persona-store.vala \
	dummy-full-persona.vala \
	$(NULL)

libfolks_dummy_la_VALAFLAGS = \
	$(backend_library_valaflags) \
	$(NULL)

libfolks_dummy_la_CPPFLAGS = \
	$(backend_library_cppflags) \
	-include folks/redeclare-internal-api.h \
	$(NULL)

libfolks_dummy_la_CFLAGS = \
	$(backend_library_cflags) \
	$(NULL)

libfolks_dummy_la_LIBADD = \
	$(backend_library_libadd) \
	$(NULL)

libfolks_dummy_la_LDFLAGS = \
	$(backend_library_ldflags) \
	$(NULL)


-include $(top_srcdir)/git.mk
