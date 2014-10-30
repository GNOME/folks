CLEANFILES =
MAINTAINERCLEANFILES =
EXTRA_DIST =

include $(top_srcdir)/backends/backend-library.mk

BACKEND_NAME = eds
BACKEND_NAME_C = Eds
BACKEND_LT_VERSION = $(FOLKS_EDS_LT_VERSION)
BACKEND_API_VERSION = $(FOLKS_EDS_API_VERSION)
BACKEND_SYMBOLS_REGEX = "^(EDSF|edsf)_.*|"
BACKEND_NAMESPACE = Edsf

lib_LTLIBRARIES = libfolks-eds.la

libfolks_eds_la_SOURCES = \
	$(backend_library_sources) \
	edsf-persona.vala \
	edsf-persona-store.vala \
	$(NULL)

libfolks_eds_la_VALAFLAGS = \
	$(backend_library_valaflags) \
	--pkg libebook-1.2 \
	--pkg libebook-contacts-1.2 \
	--pkg libedataserver-1.2 \
	--pkg libxml-2.0 \
	$(NULL)

libfolks_eds_la_CPPFLAGS = \
	$(backend_library_cppflags) \
	-include folks/redeclare-internal-api.h \
	$(NULL)

libfolks_eds_la_CFLAGS = \
	$(backend_library_cflags) \
	$(EBOOK_CFLAGS) \
	$(EDATASERVER_CFLAGS) \
	$(LIBXML_CFLAGS) \
	$(NULL)

libfolks_eds_la_LIBADD = \
	$(backend_library_libadd) \
	$(EBOOK_LIBS) \
	$(EDATASERVER_LIBS) \
	$(LIBXML_LIBS) \
	$(NULL)

libfolks_eds_la_LDFLAGS = \
	$(backend_library_ldflags) \
	$(NULL)


-include $(top_srcdir)/git.mk
