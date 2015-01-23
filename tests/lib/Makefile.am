# Build . first so that backends' test libraries can link to libfolks-test.la
SUBDIRS = \
	. \
	dummy \
	key-file \
	$(NULL)

if ENABLE_BLUEZ
if HAVE_BLUEZ_TESTS
SUBDIRS += bluez
endif
endif

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
	dummy \
	key-file \
	bluez \
	telepathy \
	eds \
	libsocialweb \
	tracker \
	$(NULL)

noinst_LTLIBRARIES = libfolks-test.la

libfolks_test_la_SOURCES = \
	disconnection-queue.vala \
	haze-remove-directory.c \
	gtestdbus.c \
	gtestdbus.h \
	folks-test-dbus.vapi \
	test-case.vala \
	test-case-helper.c \
	test-utils.vala \
	org-freedesktop-dbus-mock.vala \
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
	-DINSTALLED_TESTS_DIR=\"${libexecdir}/installed-tests/${PACKAGE_TARNAME}\" \
	-DINSTALLED_TESTS_META_DIR=\"${datadir}/installed-tests/${PACKAGE_TARNAME}\" \
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
	$(AM_VALAFLAGS) \
	$(TARGET_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--vapidir=$(abs_top_srcdir)/folks \
	--vapidir=$(abs_top_builddir)/folks \
	--vapidir=$(abs_top_srcdir)/tests/lib \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg dbus-glib-1 \
	--pkg folks \
	--pkg build-conf \
	--pkg posix \
	--library folks-test \
	--vapi folks-test.vapi \
	-H folks-test.h \
	-h folks-test-internal.h \
	-g \
	$(NULL)

# According to the following document, this is the best way to ensure that this header
# gets built when compiling the Vala sources to C but before we try to compile
# all the C files (in case of parallel builds):
#     http://www.lug.or.kr/docs/automake/Dependency-Tracking-Evolution.html
BUILT_SOURCES = \
	folks-test-internal.h \
	$(NULL)

# Too hard to add support for this in git.mk.
GITIGNOREFILES = \
	folks-test-internal.h \
	$(NULL)

EXTRA_DIST = \
	folks-test.deps \
	$(NULL)

-include $(top_srcdir)/git.mk
