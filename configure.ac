# If not 1, append datestamp to the version number
m4_define([folks_released], [0])

m4_define([folks_major_version], [0])
m4_define([folks_minor_version], [7])
m4_define([folks_micro_version], [0])
m4_define([folks_nano_version], [1])

# If library source has changed since last release, increment revision
# If public symbols have been added, removed or changed since last release,
#  increment current and set revision to 0
# If public symbols have been added since last release, increment age
# If public symbols have been removed since last release, set age to 0
m4_define([folks_lt_current], [33])
m4_define([folks_lt_revision], [0])
m4_define([folks_lt_age], [8])

# Display the nano_version only if it's not '0'
m4_define([folks_base_version],
          folks_major_version.folks_minor_version.folks_micro_version)
m4_define([folks_full_version],
          [m4_if(folks_nano_version, [0],
                 folks_base_version, folks_base_version.folks_nano_version)])

m4_define([folks_maybe_datestamp],
          m4_if(folks_released, [1],
                [], [m4_esyscmd([date +.%Y%m%d | tr -d '\n\r'])]))

m4_define([folks_version], folks_full_version[]folks_maybe_datestamp)
m4_define([folks_major_minor_version], folks_major_version.folks_minor_version)
m4_define([folks_module_version], folks_lt_current)

AC_INIT([folks], folks_version,
        [https://bugzilla.gnome.org/browse.cgi?product=folks], [folks],
        [http://telepathy.freedesktop.org/wiki/Folks])
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])

AC_PREREQ([2.65])
AC_COPYRIGHT([Copyright (C) 2010 Collabora Ltd.])

AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR([Makefile.am])
AC_CONFIG_HEADERS(config.h)
AC_CONFIG_SRCDIR([configure.ac])
AM_INIT_AUTOMAKE([1.11 dist-bzip2 no-define
                  no-dist-gzip tar-ustar -Wno-portability])
AM_MAINTAINER_MODE([enable])

AC_PROG_CC
AM_PROG_CC_C_O
AC_DISABLE_STATIC
LT_INIT
PKG_PROG_PKG_CONFIG([0.21])
GLIB_GSETTINGS

AC_SUBST([CFLAGS])
AC_SUBST([CPPFLAGS])
AC_SUBST([LDFLAGS])

LT_CURRENT=folks_lt_current
LT_REVISION=folks_lt_revision
LT_AGE=folks_lt_age
AC_SUBST([LT_CURRENT])
AC_SUBST([LT_REVISION])
AC_SUBST([LT_AGE])

FOLKS_MAJOR_MINOR_VERSION=folks_major_minor_version
AC_SUBST([FOLKS_MAJOR_MINOR_VERSION])

API_VERSION=0.6
AC_SUBST([API_VERSION])

AC_ARG_ENABLE(tracker-backend,
        AC_HELP_STRING([--enable-tracker-backend],
                       [ build the Tracker backend]),
        enable_tracker_backend=$enableval,
        enable_tracker_backend=no )

AM_CONDITIONAL([ENABLE_TRACKER], [test "x$enable_tracker_backend" = "xyes"])

if test "x$enable_tracker_backend" = "xyes"; then
        AC_DEFINE(HAVE_TRACKER, [1],
                  [Define as 1 if you have the Tracker backend])
else
        AC_DEFINE(HAVE_TRACKER, [0],
                  [Define as 1 if you have the Tracker backend])
fi

AC_ARG_ENABLE(eds-backend,
        AC_HELP_STRING([--enable-eds-backend],
                       [ build the E-D-S backend]),
        enable_eds_backend=$enableval,
        enable_eds_backend=yes )

if test "x$enable_eds_backend" = "xyes"; then
        AC_DEFINE(HAVE_EDS, [1], [Define as 1 if you have the eds backend])
else
        AC_DEFINE(HAVE_EDS, [0], [Define as 1 if you have the eds backend])
fi


AM_CONDITIONAL([ENABLE_EDS], [test "x$enable_eds_backend" = "xyes"])


AC_ARG_ENABLE(zeitgeist,
        AC_HELP_STRING([--enable-zeitgeist],
                       [ build the Zeitgeist]),
        enable_zeitgeist=$enableval,
        enable_zeitgeist=no )

AM_CONDITIONAL([ENABLE_ZEITGEIST], [test "x$enable_zeitgeist" = "xyes"])

if test "x$enable_zeitgeist" = "xyes"; then
        AC_DEFINE(HAVE_ZEITGEIST, [1],
                  [Define as 1 if you have the Zeitgeist support])
else
        AC_DEFINE(HAVE_ZEITGEIST, [0],
                  [Define as 1 if you have the Zeitgeist support])
fi


# Automatically check the dependencies for the libsocialweb backend
SW_CLIENT_REQUIRED=0.25.20
AC_ARG_ENABLE(libsocialweb-backend,
        AC_HELP_STRING([--enable-libsocialweb-backend=@<:@no/yes/auto@:>@],
                       [build the Libsocialweb backend (default: auto)]),
        enable_libsocialweb_backend=$enableval,
        enable_libsocialweb_backend=auto )

# this may be overwritten farther down
AC_DEFINE(HAVE_LIBSOCIALWEB, [0],
          [Define as 1 if you have the libsocialweb backend])
if test "x$enable_libsocialweb_backend" != "xno"; then
  PKG_CHECK_MODULES([SW_CLIENT], [libsocialweb-client >= $SW_CLIENT_REQUIRED],
      have_libsocialweb_backend="yes", have_libsocialweb_backend="no")
  if test "x$have_libsocialweb_backend" = "xyes" -a \
          "x$enable_vala" = "xyes"; then
    VALA_CHECK_PACKAGES([telepathy-glib
                         gio-2.0
                         gee-1.0
                         libsocialweb-client],
        ,
        have_libsocialweb_backend="no")
  fi

  if test "x$have_libsocialweb_backend" = "xyes"; then
    AC_DEFINE(HAVE_LIBSOCIALWEB, [1],
              [Define if you have the libsocialweb backend])
  fi
else
   have_libsocialweb_backend=no
fi

if test "x$enable_libsocialweb_backend" = "xyes" -a \
  "x$have_libsocialweb_backend" != "xyes"; then
    AC_MSG_ERROR([Cannot find libsocialweb dependencies.])
fi

AM_CONDITIONAL([ENABLE_LIBSOCIALWEB],
        [test "x$have_libsocialweb_backend" = "xyes"])

# -----------------------------------------------------------
# Dependencies
# -----------------------------------------------------------

GLIB_REQUIRED=2.26.0
VALA_REQUIRED=0.15.2
VALADOC_REQUIRED=0.3.1
TRACKER_SPARQL_MAJOR=0.14
TRACKER_SPARQL_REQUIRED=0.13.1
EBOOK_REQUIRED=3.5.3
EDATASERVER_REQUIRED=3.5.3
ZEITGEIST_REQUIRED=0.3.14

AC_SUBST([TRACKER_SPARQL_MAJOR])

PKG_CHECK_MODULES([GLIB],
                  [glib-2.0 >= $GLIB_REQUIRED
                   gobject-2.0 >= $GLIB_REQUIRED])
PKG_CHECK_MODULES([GMODULE], [gmodule-no-export-2.0])
PKG_CHECK_MODULES([GIO], [gio-2.0 >= $GLIB_REQUIRED])
PKG_CHECK_MODULES([DBUS_GLIB], [dbus-glib-1])

# FIXME: We depend on libgee < 0.7 because 0.7 breaks API. bgo#627746
PKG_CHECK_MODULES([GEE], [gee-1.0 < 0.7],
                  have_gee_0_6_x="yes",
                  have_gee_0_6_x="no")

if test "x$have_gee_0_6_x" != "xyes"; then
    AC_MSG_ERROR([
Gee 0.6.x required but not installed.

Note that Gee 0.8.x provides gee-0.8 (but gee-1.0 is, confusingly, provided by
Gee 0.6.x)])
fi

TP_GLIB_REQUIRED=0.19.0
PKG_CHECK_MODULES([TP_GLIB], [telepathy-glib >= $TP_GLIB_REQUIRED])

# Ignore post 0.20 deprecations
TP_GLIB_CFLAGS="$TP_GLIB_CFLAGS -DTP_VERSION_MIN_REQUIRED=TP_VERSION_0_20"
# Prevent post 0.20 APIs
TP_GLIB_CFLAGS="$TP_GLIB_CFLAGS -DTP_VERSION_MAX_ALLOWED=TP_VERSION_0_20"

if test x$enable_tracker_backend = xyes; then
        PKG_CHECK_MODULES([TRACKER_SPARQL],
                          [tracker-sparql-$TRACKER_SPARQL_MAJOR >= \
                           $TRACKER_SPARQL_REQUIRED])
fi

if test x$enable_eds_backend = xyes; then
        PKG_CHECK_MODULES([EBOOK], [libebook-1.2 >= $EBOOK_REQUIRED])
        PKG_CHECK_MODULES([EDATASERVER], [libedataserver-1.2 >= $EDATASERVER_REQUIRED])
fi

if test x$enable_zeitgeist = xyes; then
        PKG_CHECK_MODULES([ZEITGEIST], [zeitgeist-1.0 >= $ZEITGEIST_REQUIRED])
fi

#
# Vala building options -- allows tarball builds without installing Vala
#
AC_ARG_ENABLE([vala],
              AS_HELP_STRING([--enable-vala],
                             [Enable building from the Vala sources]),
              [enable_vala=$enableval],
              [enable_vala=no])

# will be re-set as necessary below
AM_CONDITIONAL([HAVE_INTROSPECTION], [test "x$enable_vala" = "xyes"])
sd=${srcdir}/

# Force Vala for non-release builds
m4_if(folks_released, [1], [],
    [
        enable_vala=yes
        echo "Vala compiler required for non-release builds; requiring Vala..."
    ])

# Force Vala if generated source is missing or outdated
if test \
        ! -e ${sd}tools/folks_import_vala.stamp -o \
        ! -e ${sd}tests/folks/abstract_field_details_vala.stamp -o \
        ! -e ${sd}tests/folks/aggregation_vala.stamp -o \
        ! -e ${sd}tests/folks/backend_loading_vala.stamp -o \
        ! -e ${sd}tests/key-file/individual_retrieval_vala.stamp -o \
        ! -e ${sd}tests/lib/folks-test.vapi -o \
        ! -e ${sd}tests/lib/key-file/kf-test.vapi -o \
        ! -e ${sd}tests/lib/key-file/libkf_test_la_vala.stamp -o \
        ! -e ${sd}tests/lib/telepathy/contactlist/tp-test-contactlist.gir -o \
        ! -e ${sd}tests/lib/telepathy/contactlist/tp-test-contactlist.vapi -o \
        ! -e ${sd}tests/lib/libfolks_test_la_vala.stamp -o \
        ! -e ${sd}tests/telepathy/persona_store_capabilities_vala.stamp -o \
        ! -e ${sd}tests/telepathy/individual_retrieval_vala.stamp -o \
        ! -e ${sd}tests/telepathy/individual_properties_vala.stamp -o \
        ! -e ${sd}tests/folks/backend_loading_vala.stamp -o \
        ! -e ${sd}backends/key-file/key_file_la_vala.stamp -o \
        ! -e ${sd}backends/telepathy/telepathy_la_vala.stamp \
                -o \
        ! -e ${sd}backends/telepathy/lib/folks-telepathy.vapi -o \
        ! -e ${sd}backends/telepathy/lib/tp-lowlevel.gir -o \
        ! -e ${sd}backends/telepathy/lib/tp-lowlevel.vapi -o \
        ! -e ${sd}backends/telepathy/lib/libfolks_telepathy_la_vala.stamp -o \
        ! -e ${sd}folks/folks-internal.h -o \
        ! -e ${sd}folks/folks-internal.vapi -o \
        ! -e ${sd}folks/libfolks_internal_la_vala.stamp -o \
        ! -e ${sd}folks/folks.vapi -o \
        ! -e ${sd}folks/libfolks_la_vala.stamp ; then
        enable_vala=yes
        echo "Vala source needs to be re-compiled; requiring Vala..."
fi

if test "x$enable_vala" = "xyes" ; then
        AM_PROG_VALAC([$VALA_REQUIRED])
        if test "x$VALAC" = "x"; then
              AC_MSG_ERROR([Vala requested but valac is not installed])
        fi

        AC_PATH_PROG([VAPIGEN], [vapigen], [])
        if test "x$VAPIGEN" = "x"; then
              AC_MSG_ERROR([Vala must be built with --enable-vapigen])
        fi

        # require GLib >= 2.24 so GLib.Array, etc. reffing is handled
        # automatically
        VALAFLAGS="$VALAFLAGS --target-glib=2.24"
        AC_SUBST([VALAFLAGS])
        AC_SUBST([VAPIGENFLAGS])
        AC_SUBST([VAPIDIR])

        VALA_CHECK_PACKAGES([telepathy-glib
                             gio-2.0
                             gee-1.0])

        if test x$enable_tracker_backend = xyes; then
          VALA_CHECK_PACKAGES([tracker-sparql-$TRACKER_SPARQL_MAJOR])
        fi

        if test x$enable_eds_backend = xyes; then
          VALA_CHECK_PACKAGES([libebook-1.2 libedataserver-1.2 libxml-2.0])
        fi

        if test x$enable_zeitgeist = xyes; then
          VALA_CHECK_PACKAGES([zeitgeist-1.0])
        fi

fi

# this will set HAVE_INTROSPECTION
GOBJECT_INTROSPECTION_REQUIRE([1.30])

AM_CONDITIONAL([HAVE_VALA], [test "x$enable_vala" = "xyes"])

# Various functions that we need (used in C code generated from Vala)
AC_CHECK_FUNCS([memset])
AC_CHECK_FUNCS([strstr])

# -----------------------------------------------------------
# Backends
# -----------------------------------------------------------

FOLKS_MODULE_VERSION=folks_module_version
AC_SUBST([FOLKS_MODULE_VERSION])
AC_DEFINE([MODULE_VERSION], "folks_module_version", [Module interface version])

BACKEND_DIR='$(libdir)/folks/$(FOLKS_MODULE_VERSION)/backends'
AC_SUBST([BACKEND_DIR])

BACKEND_KF='$(top_builddir)/backends/key-file/.libs/key-file.so'
AC_SUBST([BACKEND_KF])
BACKEND_TP='$(top_builddir)/backends/telepathy/.libs/telepathy.so'
AC_SUBST([BACKEND_TP])

if test x$have_libsocialweb_backend = xyes; then
  BACKEND_LIBSOCIALWEB='$(top_builddir)/backends/libsocialweb/.libs/libsocialweb.so'
  AC_SUBST([BACKEND_LIBSOCIALWEB])
fi

if test x$enable_tracker_backend = xyes; then
  BACKEND_TRACKER='$(top_builddir)/backends/tracker/.libs/tracker.so'
  AC_SUBST([BACKEND_TRACKER])
fi

if test x$enable_eds_backend = xyes; then
  BACKEND_EDS='$(top_builddir)/backends/eds/.libs/eds.so'
  AC_SUBST([BACKEND_EDS])
fi

# All of the backend libraries in our tree; to be used by the tests
BACKEND_UNINST_PATH='$(BACKEND_KF):$(BACKEND_TP)'
if test x$have_libsocialweb_backend = xyes; then
  LIBSOCIALWEB_BACKEND_UNINST_PATH='$(BACKEND_LIBSOCIALWEB)'
  BACKEND_UNINST_PATH="$BACKEND_UNINST_PATH:$LIBSOCIALWEB_BACKEND_UNINST_PATH"
fi
if test x$enable_tracker_backend = xyes; then
  TRACKER_BACKEND_UNINST_PATH='$(BACKEND_TRACKER)'
  BACKEND_UNINST_PATH="$BACKEND_UNINST_PATH:$TRACKER_BACKEND_UNINST_PATH"
fi
if test x$enable_eds_backend = xyes; then
  EDS_BACKEND_UNINST_PATH='$(BACKEND_EDS)'
  BACKEND_UNINST_PATH="$BACKEND_UNINST_PATH:$EDS_BACKEND_UNINST_PATH"
fi
AC_SUBST([BACKEND_UNINST_PATH])

# -----------------------------------------------------------
# Tools
# -----------------------------------------------------------

AC_ARG_ENABLE([import-tool],
              AS_HELP_STRING([--enable-import-tool],
                             [Enable building the meta-contact import tool]),
              [enable_import_tool=$enableval with_import_tool=$enableval],
              [enable_import_tool=maybe with_import_tool=no])
AS_IF([test "$enable_import_tool" != "no"],
      [PKG_CHECK_MODULES([LIBXML], [libxml-2.0],
                         [with_import_tool=yes], [with_import_tool=no])])
AS_IF([test "$enable_import_tool" = "yes" -a "$with_import_tool" = "no"],
      [AC_MSG_ERROR([Import tool explicitly enabled, but libxml2 not found])])
AM_CONDITIONAL([ENABLE_IMPORT_TOOL], [test "$with_import_tool" = "yes"])

# Readline's required for the folks-inspect program
AC_ARG_ENABLE([inspect-tool],
              AS_HELP_STRING([--enable-inspect-tool],
                             [Enable building the data inspection tool]),
              [enable_inspect_tool=$enableval with_inspect_tool=$enableval],
              [enable_inspect_tool=maybe with_inspect_tool=no])
AS_IF([test "$enable_inspect_tool" = "yes" -a "$enable_vala" != "yes"],
      [AC_MSG_ERROR([Inspect tool explicitly enabled, but Vala wasn't enabled \
                     using --enable-vala])])
AS_IF([test "$enable_inspect_tool" = "maybe" -a "$enable_vala" != "yes"],
      [AC_MSG_NOTICE([Inspect tool disabled, as Vala wasn't enabled using \
                      --enable-vala])])
AS_IF([test "$enable_inspect_tool" != "no" -a "x$enable_vala" = "xyes"],
      [AC_CHECK_LIB([readline], [main],
                    [with_inspect_tool=yes], [with_inspect_tool=no],
                    [-lncurses])])
AS_IF([test "$enable_inspect_tool" != "no" -a "$with_inspect_tool" = "yes" -a \
       "x$enable_vala" = "xyes"],
      [VALA_CHECK_PACKAGES([readline])
       LIBREADLINE="-lreadline -lncurses"
       AC_DEFINE([HAVE_LIBREADLINE], [1], [Define if you have libreadline])
       AC_SUBST([LIBREADLINE])])
AS_IF([test "$enable_inspect_tool" = "yes" -a "$with_inspect_tool" = "no"],
      [AC_MSG_ERROR([Inspect tool explicitly enabled, but readline not found])])
AM_CONDITIONAL([ENABLE_INSPECT_TOOL], [test "$with_inspect_tool" = "yes"])

# -----------------------------------------------------------
# Documentation
# -----------------------------------------------------------

AC_ARG_ENABLE([docs],
              AS_HELP_STRING([--enable-docs],[Enable documentation generation]),
              [enable_docs=$enableval], [enable_docs=no])
AM_CONDITIONAL([ENABLE_DOCS], [test x$enable_docs = xyes])

have_valadoc=no
if test x$enable_docs = xyes; then
  # make sure the library is new enough and the program exists
  PKG_CHECK_MODULES([VALADOC], [valadoc-1.0 >= $VALADOC_REQUIRED])
  AC_PATH_PROG([VALADOC], [valadoc], [:])
  AS_IF([test "$VALADOC" != :], have_valadoc=yes)
fi
AM_CONDITIONAL([HAVE_VALADOC], [test x$have_valadoc = xyes])

if test "x$enable_docs" = "xyes" -a "x$have_valadoc" != "xyes"; then
    AC_MSG_ERROR([Doc building requested but valadoc not installed.])
fi

# -----------------------------------------------------------
# Gettext
# -----------------------------------------------------------

GETTEXT_PACKAGE=AC_PACKAGE_NAME
AC_SUBST(GETTEXT_PACKAGE)
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE, ["$GETTEXT_PACKAGE"], [Define the gettext package to be used])
IT_PROG_INTLTOOL([0.50.0])

# -----------------------------------------------------------
# Error flags
# -----------------------------------------------------------

# Disable GLib deprecation warnings for now (#670196); GValueArray is deprecated
# but we need it for dbus-glib. Porting to GDBus will solve this (#653198)
AC_DEFINE(GLIB_DISABLE_DEPRECATION_WARNINGS, 1, [Build with GLib deprecated])

AS_COMPILER_FLAG([-Wall], [ERROR_CFLAGS="-Wall"], [ERROR_CFLAGS=""])
AS_COMPILER_FLAG([-Werror], [werror=yes], [werror=no])

AC_ARG_ENABLE([debug],
              AS_HELP_STRING([--disable-debug],[compile without debug code]),
              [enable_debug=$enableval], [enable_debug=yes])

AC_ARG_ENABLE([Werror],
              AS_HELP_STRING([--disable-Werror],
                             [compile without -Werror (normally enabled in
                              development builds)]),
              [werror=$enableval], [werror=yes])

AS_COMPILER_FLAG([-Wextra], [wextra=yes], [wextra=no])
AS_COMPILER_FLAG([-Wno-missing-field-initializers],
                 [wno_missing_field_initializers=yes],
                 [wno_missing_field_initializers=no])
AS_COMPILER_FLAG([-Wno-unused-parameter],
                 [wno_unused_parameter=yes], [wno_unused_parameter=no])

m4_if(folks_released, [1], [],
    [
        if test x$werror = xyes; then
            ERROR_CFLAGS="$ERROR_CFLAGS -Werror"
        fi
        if test x$wextra = xyes -a \
            x$wno_missing_field_initializers = xyes -a \
            x$wno_unused_parameter = xyes; then
            ERROR_CFLAGS="$ERROR_CFLAGS -Wextra \
                -Wno-missing-field-initializers -Wno-unused-parameter"
        fi
    ])

AS_COMPILER_FLAG([-D_POSIX_SOURCE], [ERROR_CFLAGS="$ERROR_CFLAGS -D_POSIX_SOURCE"])
AS_COMPILER_FLAG([-std=c99], [ERROR_CFLAGS="$ERROR_CFLAGS -std=c99"])
AS_COMPILER_FLAG([-Wshadow], [ERROR_CFLAGS="$ERROR_CFLAGS -Wshadow"])
AS_COMPILER_FLAG([-Wmissing-prototypes], [ERROR_CFLAGS="$ERROR_CFLAGS \
                                          -Wmissing-prototypes"])
AS_COMPILER_FLAG([-Wmissing-declarations], [ERROR_CFLAGS="$ERROR_CFLAGS \
                                            -Wmissing-declarations"])
AS_COMPILER_FLAG([-Wstrict-prototypes], [ERROR_CFLAGS="$ERROR_CFLAGS \
                                         -Wstrict-prototypes"])

AC_SUBST([ERROR_CFLAGS])

# -----------------------------------------------------------
# Code coverage flags
# -----------------------------------------------------------

AC_ARG_ENABLE([code-coverage],
              AS_HELP_STRING([--enable-code-coverage],
                             [compile with code coverage code]),
              [enable_code_coverage=$enableval], [enable_code_coverage=no])

# Only enable code coverage if this isn't a release.
m4_if(folks_released, [1], [],
    [
        if test "x$GCC" = "xyes"; then
            if test "x$enable_code_coverage" = "xyes"; then
                CODE_COVERAGE_CFLAGS="-fprofile-arcs -ftest-coverage -O0 -ggdb"
                CODE_COVERAGE_LDFLAGS="-lgcov"
            fi
        fi
    ])

AC_SUBST([CODE_COVERAGE_CFLAGS])
AC_SUBST([CODE_COVERAGE_LDFLAGS])

# Vala-related flags
AC_ARG_ENABLE([fatal-warnings],
              AS_HELP_STRING([--disable-fatal-warnings],
                             [Make warnings from valac and g-ir-scanner non-fatal]),
              [enable_fatal_warnings=$enableval], [enable_fatal_warnings=yes])
AS_IF([test "x$enable_vala" = "xyes" && test "x$enable_fatal_warnings" = "xyes"],
      [ERROR_INTROSPECTION_SCANNER_ARGS="\
                        $ERROR_INTROSPECTION_SCANNER_ARGS --warn-error"
       ERROR_VALAFLAGS="$ERROR_VALAFLAGS --fatal-warnings"])

# Disable -g if we're building with code coverage enabled, since Vala's
# insertion of #line directives into .c files confuses lcov. For the moment,
# we'll have to do with looking at code coverage of the generated C files only.
# We set the debug flags in CODE_COVERAGE_CFLAGS instead in that case.
m4_if(folks_released, [1], [],
    [
        if test "x$enable_code_coverage" != "xyes" -o "x$GCC" != "xyes"; then
            ERROR_VALAFLAGS="$ERROR_VALAFLAGS -g"
        fi
    ])

AC_SUBST([ERROR_INTROSPECTION_SCANNER_ARGS])
AC_SUBST([ERROR_VALAFLAGS])

# -----------------------------------------------------------
# Final output
# -----------------------------------------------------------

# FIXME: We can't remove gconf.path until bgo#635379 is fixed, since we need to
# safely contain EDS' use of GConf for the EDS backend tests.
# Note that our use of gconf.path doesn't actually need GConf to be installed,
# though, so it's not a hard dependency of folks.

AC_CONFIG_FILES([
    backends/telepathy/lib/folks-telepathy.pc
    backends/telepathy/lib/folks-telepathy-uninstalled.pc
    backends/tracker/lib/folks-tracker.deps
    backends/tracker/lib/folks-tracker.pc
    backends/tracker/lib/folks-tracker-uninstalled.pc
    backends/eds/lib/folks-eds.pc
    backends/eds/lib/folks-eds-uninstalled.pc
    folks/folks.pc
    folks/folks-uninstalled.pc
    folks/org.freedesktop.folks.gschema.xml
    Makefile
    backends/Makefile
    backends/key-file/Makefile
    backends/libsocialweb/Makefile
    backends/libsocialweb/lib/Makefile
    backends/libsocialweb/lib/folks-libsocialweb.pc
    backends/libsocialweb/lib/folks-libsocialweb-uninstalled.pc
    backends/telepathy/Makefile
    backends/telepathy/lib/Makefile
    backends/tracker/Makefile
    backends/tracker/lib/Makefile
    backends/eds/Makefile
    backends/eds/lib/Makefile
    folks/Makefile
    docs/Makefile
    po/Makefile.in
    tests/Makefile
    tests/data/Makefile
    tests/data/gconf.path
    tests/folks/Makefile
    tests/key-file/Makefile
    tests/libsocialweb/Makefile
    tests/telepathy/Makefile
    tests/tracker/Makefile
    tests/lib/Makefile
    tests/lib/folks-test-uninstalled.pc
    tests/lib/key-file/Makefile
    tests/lib/libsocialweb/Makefile
    tests/lib/libsocialweb/session.conf
    tests/eds/Makefile
    tests/lib/eds/Makefile
    tests/lib/telepathy/Makefile
    tests/lib/tracker/Makefile
    tests/lib/telepathy/contactlist/Makefile
    tests/lib/telepathy/contactlist/session.conf
    tests/tools/Makefile
    tools/Makefile
    tools/inspect/Makefile
])

AC_OUTPUT

echo "
Configure summary:

        Vala........................:  ${enable_vala}
        Vala Compiler...............:  ${VALAC}
        C Compiler Flags............:  ${CFLAGS} ${ERROR_CFLAGS} ${CODE_COVERAGE_CFLAGS}
        Linker Flags................:  ${LDFLAGS} ${CODE_COVERAGE_LDFLAGS}
        Prefix......................:  ${prefix}
        Bugreporting URL............:  ${PACKAGE_BUGREPORT}
        Documentation...............:  ${have_valadoc}
        Import tool.................:  ${with_import_tool}
        Inspector tool..............:  ${with_inspect_tool}
        Tracker backend.............:  ${enable_tracker_backend}
        Libsocialweb backend........:  ${have_libsocialweb_backend}
        E-D-S backend...............:  ${enable_eds_backend}
        Zeitgeist support...........:  ${enable_zeitgeist}

"
