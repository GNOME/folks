SUBDIRS = lib .

include $(top_srcdir)/backends/backend.mk
BACKEND_NAME = "telepathy"

backenddir = $(BACKEND_DIR)/telepathy
backend_LTLIBRARIES = telepathy.la

telepathy_la_VALAFLAGS = \
	$(backend_valaflags) \
	--vapidir=$(top_srcdir)/backends/telepathy/lib \
	--vapidir=$(top_builddir)/backends/telepathy/lib \
	--pkg folks-telepathy \
	--pkg telepathy-glib \
	$(NULL)

telepathy_la_SOURCES = \
	$(backend_sources) \
	tp-backend.vala \
	tp-backend-factory.vala \
	$(NULL)

telepathy_la_CPPFLAGS = \
	$(backend_cppflags) \
	-I$(top_srcdir)/backends/telepathy/lib \
	-I$(top_srcdir)/backends/telepathy/lib/folks \
	$(NULL)

telepathy_la_CFLAGS = \
	$(backend_cflags) \
	$(TP_GLIB_CFLAGS) \
	$(NULL)

telepathy_la_LIBADD = \
	$(backend_libadd) \
	$(top_builddir)/backends/telepathy/lib/libfolks-telepathy.la \
	$(TP_GLIB_LIBS) \
	$(NULL)

telepathy_la_LDFLAGS = \
	-module -avoid-version \
	$(backend_ldflags) \
	$(NULL)

-include $(top_srcdir)/git.mk
