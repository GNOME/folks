# Build . first so that backends' test libraries can link to libfolks-test.la
SUBDIRS = \
	. \
	key-file \
	$(NULL)

if ENABLE_TELEPATHY
# Build the contactlist first because autotools fails to recognize the
# dependencies implicitly. There may be a better way to fix this, but then I'd
# have to spend more time working with autotools.
SUBDIRS += \
	telepathy/contactlist \
	telepathy \
	$(NULL)
endif

if ENABLE_LIBSOCIALWEB
SUBDIRS += libsocialweb
endif

if ENABLE_TRACKER
SUBDIRS += tracker
endif

if ENABLE_EDS
SUBDIRS += eds
endif

DIST_SUBDIRS = \
	key-file \
	telepathy \
	eds \
	libsocialweb \
	tracker \
	$(NULL)

noinst_LTLIBRARIES = libfolks-test.la

libfolks_test_la_SOURCES = \
	haze-remove-directory.c \
	test-case.vala \
	test-case-helper.c \
	test-utils.vala \
	$(NULL)

libfolks_test_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(DBUS_GLIB_CFLAGS) \
	$(NULL)

libfolks_test_la_CPPFLAGS = \
	$(AM_CPPFLAGS) \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-DABS_TOP_SRCDIR=\"${abs_top_srcdir}\" \
	-DABS_TOP_BUILDDIR=\"${abs_top_builddir}\" \
	-DPKGLIBEXECDIR=\"${pkglibexecdir}\" \
	-DPACKAGE_DATADIR=\"${pkgdatadir}\" \
	$(NULL)

libfolks_test_la_LIBADD = \
	$(AM_LIBADD) \
	$(top_builddir)/folks/libfolks.la \
	$(GLIB_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(DBUS_GLIB_LIBS) \
	$(NULL)

libfolks_test_la_VALAFLAGS = \
	$(ERROR_VALAFLAGS) \
	$(AM_VALAFLAGS) \
	--vapidir=$(abs_top_srcdir)/folks \
	--vapidir=$(abs_top_builddir)/folks \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg dbus-glib-1 \
	--pkg folks \
	--pkg build-conf \
	--library folks-test \
	-H folks-test.h \
	-h folks-test-internal.h \
	-g \
	$(NULL)

BUILT_SOURCES = \
	libfolks_test_la_vala.stamp \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala,$(libfolks_test_la_SOURCES))) \
	libfolks_test_la_vala.stamp \
	folks-test.h \
	folks-test.vapi \
	$(NULL)

EXTRA_DIST = \
	folks-test.deps \
	$(MAINTAINERCLEANFILES) \
	$(NULL)

-include $(top_srcdir)/git.mk
