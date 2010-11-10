AM_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/tests/lib \
	-include $(CONFIG_HEADER) \
	$(NULL)

LDADD = \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(top_builddir)/folks/libfolks.la \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(GIO_LIBS) \
	$(NULL)

AM_VALAFLAGS = \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/tests/lib \
	--vapidir=$(top_srcdir)/tests/lib/key-file \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--pkg folks \
	--pkg folks-test \
	$(NULL)

# in order from least to most complex
noinst_PROGRAMS = \
	backend-loading \
	$(NULL)

backend_store_key_file=$(top_srcdir)/tests/data/backend-store-all.ini
TESTS_ENVIRONMENT = \
	FOLKS_BACKEND_PATH=$(BACKEND_UNINST_PATH) \
	FOLKS_BACKEND_STORE_KEY_FILE_PATH=$(backend_store_key_file) \
	$(NULL)

TESTS = $(noinst_PROGRAMS)

backend_loading_SOURCES = \
	backend-loading.vala \
	$(NULL)

CLEANFILES = \
        $(addsuffix .c,$(noinst_PROGRAMS)) \
        backend_loading_vala.stamp \
        *.pid \
        *.address \
        $(TESTS) \
        $(NULL)

-include $(top_srcdir)/git.mk
