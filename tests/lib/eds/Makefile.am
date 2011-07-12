VALAFLAGS += \
	--library=eds-test \
	--header=eds-test.h \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/eds/lib \
	--vapidir=$(top_srcdir)/backends/eds/vapi \
	--vapidir=. \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--pkg folks \
	--pkg libebook-1.2 \
	--pkg libedataserver-1.2 \
	--pkg libxml-2.0 \
	--pkg folks-eds \
	$(NULL)

noinst_LTLIBRARIES = libeds-test.la

libeds_test_la_SOURCES = \
	backend.vala \
	$(NULL)

libeds_test_la_CFLAGS = \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(EBOOK_CFLAGS) \
	$(EDATASERVER_CFLAGS) \
	-I$(top_srcdir)/backends/eds/lib \
	$(NULL)

libeds_test_la_LIBADD = \
	$(top_builddir)/folks/libfolks.la \
	$(top_builddir)/backends/eds/libfolks-backend-eds.la \
	$(EBOOK_LIBS) \
	$(EDATASERVER_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

MAINTAINERCLEANFILES = \
	eds-test.vapi \
	eds-test.h \
	$(NULL)

EXTRA_DIST = \
	eds-test.vapi \
	eds-test.h \
	$(NULL)

GITIGNOREFILES = \
	$(libeds_test_la_SOURCES:.vala=.c) \
	libeds_test_la_vala.stamp \
	$(NULL)

-include $(top_srcdir)/git.mk
