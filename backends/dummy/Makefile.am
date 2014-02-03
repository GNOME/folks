SUBDIRS = lib .

BACKEND_NAME = "dummy"

backenddir = $(BACKEND_DIR)/dummy
backend_LTLIBRARIES = dummy.la

dummy_la_VALAFLAGS = \
	$(backend_valaflags) \
	--vapidir=$(top_builddir)/backends/dummy/lib \
	--pkg folks-dummy \
	$(NULL)

dummy_la_SOURCES = \
	$(backend_sources) \
	dummy-backend-factory.vala \
	$(NULL)

dummy_la_CPPFLAGS = \
	$(backend_cppflags) \
	-I$(top_srcdir)/backends/dummy/lib \
	-I$(top_srcdir)/backends/dummy/lib/folks \
	$(NULL)

dummy_la_CFLAGS = \
	$(backend_cflags) \
	$(NULL)

dummy_la_LIBADD = \
	$(backend_libadd) \
	$(top_builddir)/backends/dummy/lib/libfolks-dummy.la \
	$(NULL)

dummy_la_LDFLAGS = \
	-module -avoid-version \
	$(backend_ldflags) \
	$(NULL)

-include $(top_srcdir)/backends/backend.mk
-include $(top_srcdir)/git.mk
