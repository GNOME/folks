AM_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/tests/lib \
	-I$(top_srcdir)/tests/lib/key-file \
	-include $(CONFIG_HEADER) \
	$(NULL)

LDADD = \
	$(top_builddir)/tests/lib/key-file/libkf-test.la \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(top_builddir)/folks/libfolks.la \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
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
	--pkg kf-test \
	$(NULL)

# in order from least to most complex
noinst_PROGRAMS = \
	individual-retrieval \
	$(NULL)

TESTS = $(noinst_PROGRAMS)

individual_retrieval_SOURCES = \
	individual-retrieval.vala \
	$(NULL)

CLEANFILES = \
        $(addsuffix .c,$(noinst_PROGRAMS)) \
        individual_retrieval_vala.stamp \
        *.pid \
        *.address \
        $(TESTS) \
        $(NULL)

-include $(top_srcdir)/git.mk
