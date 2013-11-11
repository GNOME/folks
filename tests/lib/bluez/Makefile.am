noinst_LTLIBRARIES = libbluez-test.la

libbluez_test_la_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	$(TARGET_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--library bluez-test \
	--vapi bluez-test.vapi \
	--header bluez-test.h \
	--vapidir=$(abs_srcdir) \
	--vapidir=$(abs_builddir) \
	--vapidir=$(abs_top_srcdir)/folks \
	--vapidir=$(abs_top_builddir)/folks \
	--vapidir=$(abs_top_srcdir)/tests/lib \
	--vapidir=$(abs_top_builddir)/tests/lib \
	--pkg folks-test \
	--pkg folks-test-dbus \
	-g \
	$(NULL)

libbluez_test_la_SOURCES = \
	backend.vala \
	test-case.vala \
	$(NULL)

libbluez_test_la_CPPFLAGS = \
	$(AM_CPPFLAGS) \
	-include $(top_srcdir)/folks/warnings.h \
	$(NULL)

libbluez_test_la_CFLAGS = \
	-I$(top_srcdir) \
	-I$(top_srcdir)/tests/lib \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

libbluez_test_la_LIBADD = \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

EXTRA_DIST = \
	bluez-test.vapi \
	bluez-test.h \
	$(NULL)

-include $(top_srcdir)/git.mk
