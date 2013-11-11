SUBDIRS = lib .

include $(top_srcdir)/backends/backend.mk
BACKEND_NAME = "tracker"

backenddir = $(BACKEND_DIR)/tracker
backend_LTLIBRARIES = tracker.la

tracker_la_VALAFLAGS = \
	$(backend_valaflags) \
	--vapidir=$(top_builddir)/backends/tracker/lib \
	--pkg folks-tracker \
	--pkg tracker-sparql-$(TRACKER_SPARQL_MAJOR) \
	$(NULL)

tracker_la_SOURCES = \
	$(backend_sources) \
	tr-backend.vala \
	tr-backend-factory.vala \
	$(NULL)

tracker_la_CPPFLAGS = \
	$(backend_cppflags) \
	-I$(top_srcdir)/backends/tracker/lib \
	-I$(top_srcdir)/backends/tracker/lib/folks \
	$(NULL)

tracker_la_CFLAGS = \
	$(backend_cflags) \
	$(TRACKER_SPARQL_CFLAGS) \
	$(NULL)

tracker_la_LIBADD = \
	$(backend_libadd) \
	$(top_builddir)/backends/tracker/lib/libfolks-tracker.la \
	$(TRACKER_SPARQL_LIBS) \
	$(NULL)

tracker_la_LDFLAGS = \
	-module -avoid-version \
	$(backend_ldflags) \
	$(NULL)

-include $(top_srcdir)/git.mk
