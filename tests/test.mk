#
# Common build variable values for folks tests.
#
# There are no required variables or targets. The variables defined here will
# apply to all Makefile targets.
#
# Note that this file must be included before any of the variables it defines
# are defined, as it does not append to them.
#
# Defined variables (these must be included in the test-specific variables):
#  - test_valaflags
#  - test_cppflags
#  - test_cflags
#  - test_ldadd
# The defined variables include flags for the standard dependencies:
#  - folks
#  - folks-test
#  - GIO
#  - GLib
#  - libgee
# but do *not* include the relevant $(AM_*) variables.

test_valaflags = \
	$(TARGET_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_builddir)/folks \
	--vapidir=$(top_srcdir)/tests/lib \
	--vapidir=$(top_srcdir)/backends/dummy/lib \
	--vapidir=$(top_builddir)/backends/dummy/lib \
	--pkg folks \
	--pkg folks-test \
	--pkg folks-test-dbus \
	--pkg folks-dummy \
	--pkg gee-0.8 \
	--pkg gio-2.0 \
	--pkg gobject-2.0 \
	-g \
	$(NULL)

test_cppflags = \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/tests/lib \
	-I$(top_srcdir)/backends/dummy/lib \
	-include $(CONFIG_HEADER) \
	-include $(top_srcdir)/folks/warnings.h \
	$(NULL)

test_cflags = \
	$(ERROR_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

test_ldadd = \
	$(top_builddir)/folks/libfolks.la \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(top_builddir)/backends/dummy/lib/libfolks-dummy.la \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(NULL)
