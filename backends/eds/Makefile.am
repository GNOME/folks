SUBDIRS = lib .

include $(top_srcdir)/backends/backend.mk
BACKEND_NAME = "eds"

backenddir = $(BACKEND_DIR)/eds
backend_LTLIBRARIES = eds.la

eds_la_VALAFLAGS = \
	$(backend_valaflags) \
	--vapidir=$(top_builddir)/backends/eds/lib \
	--pkg folks-eds \
	--pkg libebook-1.2 \
	--pkg libedataserver-1.2 \
	--pkg libxml-2.0 \
	$(NULL)

eds_la_SOURCES = \
	$(backend_sources) \
	eds-backend.vala \
	eds-backend-factory.vala \
	$(NULL)

eds_la_CPPFLAGS = \
	$(backend_cppflags) \
	-I$(top_srcdir)/backends/eds/lib \
	-I$(top_srcdir)/backends/eds/lib/folks \
	$(NULL)

eds_la_CFLAGS = \
	$(backend_cflags) \
	$(EBOOK_CFLAGS) \
	$(EDATASERVER_CFLAGS) \
	$(LIBXML_CFLAGS) \
	$(NULL)

eds_la_LIBADD = \
	$(backend_libadd) \
	$(top_builddir)/backends/eds/lib/libfolks-eds.la \
	$(EBOOK_LIBS) \
	$(EDATASERVER_LIBS) \
	$(LIBXML_LIBS) \
	$(NULL)

eds_la_LDFLAGS = \
	-module -avoid-version \
	$(backend_ldflags) \
	$(NULL)

-include $(top_srcdir)/git.mk
