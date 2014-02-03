CLEANFILES =
MAINTAINERCLEANFILES =
EXTRA_DIST =

include $(top_srcdir)/backends/backend-library.mk

BACKEND_NAME = tracker
BACKEND_NAME_C = Tracker
BACKEND_LT_VERSION = $(FOLKS_TRACKER_LT_VERSION)
BACKEND_API_VERSION = $(FOLKS_TRACKER_API_VERSION)
BACKEND_SYMBOLS_REGEX = "^(TRF|trf)_.*|"
BACKEND_NAMESPACE = Trf

lib_LTLIBRARIES = libfolks-tracker.la

libfolks_tracker_la_SOURCES = \
	$(backend_library_sources) \
	trf-persona.vala \
	trf-persona-store.vala \
	trf-util.vala \
	$(NULL)

libfolks_tracker_la_VALAFLAGS = \
	$(backend_library_valaflags) \
	--pkg tracker-sparql-$(TRACKER_SPARQL_MAJOR) \
	$(NULL)

libfolks_tracker_la_CPPFLAGS = \
	$(backend_library_cppflags) \
	$(NULL)

libfolks_tracker_la_CFLAGS = \
	$(backend_library_cflags) \
	$(TRACKER_SPARQL_CFLAGS) \
	$(NULL)

libfolks_tracker_la_LIBADD = \
	$(backend_library_libadd) \
	$(TRACKER_SPARQL_LIBS) \
	$(NULL)

libfolks_tracker_la_LDFLAGS = \
	$(backend_library_ldflags) \
	$(NULL)


-include $(top_srcdir)/git.mk
