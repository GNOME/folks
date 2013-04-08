SUBDIRS = \
        contactlist \
        $(NULL)

AM_VALAFLAGS += \
	$(ERROR_VALAFLAGS) \
	--library=tpf-test \
	--header=tpf-test.h \
	--vapidir=$(abs_srcdir) \
	--vapidir=$(abs_builddir) \
	--vapidir=$(abs_srcdir)/contactlist \
	--vapidir=$(abs_builddir)/contactlist \
	--vapidir=$(abs_top_srcdir)/folks \
	--vapidir=$(abs_top_builddir)/folks \
	--vapidir=$(abs_top_srcdir)/tests/lib \
	--vapidir=$(abs_top_builddir)/tests/lib \
	--vapidir=$(abs_top_srcdir)/tests/lib/key-file \
	--vapidir=$(abs_top_builddir)/tests/lib/key-file \
	--pkg folks-test \
	--pkg kf-test \
	--pkg tp-test-contactlist \
	-g \
	$(NULL)

noinst_LTLIBRARIES = libtpf-test.la

libtpf_test_la_SOURCES = \
	test-case.vala \
	$(NULL)

libtpf_test_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	-I$(top_srcdir) \
	-I$(top_srcdir)/tests/lib \
	-I$(top_srcdir)/tests/lib/key-file \
	-I$(srcdir)/contactlist \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	$(NULL)

libtpf_test_la_LIBADD = \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(top_builddir)/tests/lib/key-file/libkf-test.la \
	contactlist/libtp-test-contactlist.la \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(TP_GLIB_LIBS) \
	$(NULL)

MAINTAINERCLEANFILES = \
	tpf-test.vapi \
	tpf-test.h \
	$(NULL)

EXTRA_DIST = \
	tpf-test.deps \
	tpf-test.vapi \
	tpf-test.h \
	$(NULL)

BUILT_SOURCES = \
	libtpf_test_la_vala.stamp \
	$(NULL)

GITIGNOREFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala,$(libtpf_test_la_SOURCES))) \
	libtpf_test_la_vala.stamp \
	$(NULL)

-include $(top_srcdir)/git.mk
