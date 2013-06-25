# If not 1, append datestamp to the version number
m4_define([folks_released], [0])

m4_define([folks_major_version], [0])
m4_define([folks_minor_version], [9])
m4_define([folks_micro_version], [3])
m4_define([folks_nano_version], [1])

# If library source has changed since last release, increment revision
# If public symbols have been added, removed or changed since last release,
#  increment current and set revision to 0
# If public symbols have been added since last release, increment age
# If public symbols have been removed since last release, set age to 0
m4_define([folks_lt_current], [39])
m4_define([folks_lt_revision], [1])
m4_define([folks_lt_age], [14])

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
AM_INIT_AUTOMAKE([1.11 dist-xz no-define
                  no-dist-gzip tar-ustar -Wno-portability color-tests])
AM_MAINTAINER_MODE([enable])

AC_PROG_CC
AM_PROG_CC_C_O
AC_DISABLE_STATIC
LT_INIT
PKG_PROG_PKG_CONFIG([0.21])
GLIB_GSETTINGS

# Always look for .pc files in /folks so backend support libraries can be
# introspected properly
PKG_CONFIG_PATH=$(pwd)/folks:$PKG_CONFIG_PATH
AC_SUBST([PKG_CONFIG_PATH])

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

API_VERSION_MAJOR=0
AC_SUBST([API_VERSION_MAJOR])
API_VERSION_MINOR=6
AC_SUBST([API_VERSION_MINOR])
API_VERSION_DOT=$API_VERSION_MAJOR.$API_VERSION_MINOR
AC_SUBST([API_VERSION_DOT])

AC_ARG_ENABLE(tracker-backend,
        AC_HELP_STRING([--enable-tracker-backend],
                       [ build the Tracker backend]),
        enable_tracker_backend=$enableval,
        enable_tracker_backend=no )

AM_CONDITIONAL([ENABLE_TRACKER], [test "x$enable_tracker_backend" = "xyes"])

AS_IF([test "x$enable_tracker_backend" = "xyes"], [
        AC_DEFINE(HAVE_TRACKER, [1],
                  [Define as 1 if you have the Tracker backend])
], [
        AC_DEFINE(HAVE_TRACKER, [0],
                  [Define as 1 if you have the Tracker backend])
])

AC_ARG_ENABLE(eds-backend,
        AC_HELP_STRING([--enable-eds-backend],
                       [ build the E-D-S backend]),
        enable_eds_backend=$enableval,
        enable_eds_backend=yes )

AS_IF([test "x$enable_eds_backend" = "xyes"], [
        AC_DEFINE(HAVE_EDS, [1], [Define as 1 if you have the eds backend])
], [
        AC_DEFINE(HAVE_EDS, [0], [Define as 1 if you have the eds backend])
])

AM_CONDITIONAL([ENABLE_EDS], [test "x$enable_eds_backend" = "xyes"])

AC_ARG_ENABLE(ofono-backend,
	AC_HELP_STRING([--enable-ofono-backend],
		       [ build the ofono backend]),
	enable_ofono_backend=$enableval,
	enable_ofono_backend=yes )

AS_IF([test "x$enable_ofono_backend" = "xyes"], [
        AC_DEFINE(HAVE_OFONO, [1], [Define as 1 if you have the ofono backend])
], [
        AC_DEFINE(HAVE_OFONO, [0], [Define as 1 if you have the ofono backend])
])

AM_CONDITIONAL([ENABLE_OFONO], [test "x$enable_ofono_backend" = "xyes"])

AC_ARG_ENABLE(telepathy-backend,
        AC_HELP_STRING([--enable-telepathy-backend],
                       [ build the Telepathy backend]),
        enable_telepathy_backend=$enableval,
        enable_telepathy_backend=yes )

AS_IF([test "x$enable_telepathy_backend" = "xyes"], [
        AC_DEFINE(HAVE_TELEPATHY, [1], [Define as 1 if you have the Telepathy backend])
], [
        AC_DEFINE(HAVE_TELEPATHY, [0], [Define as 1 if you have the Telepathy backend])
])

AM_CONDITIONAL([ENABLE_TELEPATHY], [test "x$enable_telepathy_backend" = "xyes"])

AC_ARG_ENABLE(zeitgeist,
        AC_HELP_STRING([--enable-zeitgeist],
                       [ build Zeitgeist support in the Telepathy backend]),
        enable_zeitgeist=$enableval,
        enable_zeitgeist=auto)

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
AS_IF([test "x$enable_libsocialweb_backend" != "xno"], [
  PKG_CHECK_MODULES([SW_CLIENT], [libsocialweb-client >= $SW_CLIENT_REQUIRED],
      have_libsocialweb_backend="yes", have_libsocialweb_backend="no")
  AS_IF([test "x$have_libsocialweb_backend" = "xyes" -a \
          "x$enable_vala" = "xyes"], [
    VALA_CHECK_PACKAGES([telepathy-glib
                         gio-2.0
                         gee-0.8
                         libsocialweb-client],
        ,
        have_libsocialweb_backend="no")
  ])

  AS_IF([test "x$have_libsocialweb_backend" = "xyes"], [
    AC_DEFINE(HAVE_LIBSOCIALWEB, [1],
              [Define if you have the libsocialweb backend])
  ])
], [
   have_libsocialweb_backend=no
])

AS_IF([test "x$enable_libsocialweb_backend" = "xyes" -a \
  "x$have_libsocialweb_backend" != "xyes"], [
    AC_MSG_ERROR([Cannot find libsocialweb dependencies.])
])

AM_CONDITIONAL([ENABLE_LIBSOCIALWEB],
        [test "x$have_libsocialweb_backend" = "xyes"])

# -----------------------------------------------------------
# Dependencies
# -----------------------------------------------------------

GLIB_REQUIRED=2.32.0
VALA_REQUIRED=0.17.6
VALADOC_REQUIRED=0.3.1
TRACKER_SPARQL_MAJOR=0.16
TRACKER_SPARQL_REQUIRED=0.15.2
EBOOK_REQUIRED=3.8.1
EDATASERVER_REQUIRED=3.5.3.1
ZEITGEIST_REQUIRED=0.9.14
GEE_REQUIRED=0.8.4

AC_SUBST([TRACKER_SPARQL_MAJOR])

PKG_CHECK_MODULES([GLIB],
                  [glib-2.0 >= $GLIB_REQUIRED
                   gobject-2.0 >= $GLIB_REQUIRED])
PKG_CHECK_MODULES([GMODULE], [gmodule-no-export-2.0])
PKG_CHECK_MODULES([GIO], [gio-2.0 >= $GLIB_REQUIRED])
# FIXME: get rid of this when our dependencies stop using dbus-1 (GNOME#696177)
PKG_CHECK_MODULES([DBUS_GLIB], [dbus-glib-1 dbus-1])

PKG_CHECK_MODULES([GEE], [gee-0.8 >= $GEE_REQUIRED])

TP_GLIB_REQUIRED=0.19.0

AS_IF([test x$enable_telepathy_backend = xyes], [
        PKG_CHECK_MODULES([TP_GLIB], [telepathy-glib >= $TP_GLIB_REQUIRED])])
case "x$enable_zeitgeist" in
  xyes)
    AS_IF([test x$enable_telepathy_backend = xyes],
          [PKG_CHECK_MODULES([ZEITGEIST], [zeitgeist-2.0 >= $ZEITGEIST_REQUIRED],
           ,
           [AC_MSG_ERROR([Zeitgeist support requires Zeitgeist development package])])])
    have_zeitgeist=yes
    ;;
  xauto)
    AS_IF([test x$enable_telepathy_backend = xyes],
          [PKG_CHECK_MODULES([ZEITGEIST], [zeitgeist-2.0 >= $ZEITGEIST_REQUIRED],
                             have_zeitgeist="yes",have_zeitgeist="no")],
          [have_zeitgeist=no])
    ;;
  xno)
    have_zeitgeist=no
    ;;
  x*)
    AC_MSG_ERROR([Unknown --enable-zeitgeist argument: $enable_zeitgeist])
esac

AS_IF([test "x$have_zeitgeist" == "xyes"], [
   ZEITGEIST_VALAFLAGS="-D HAVE_ZEITGEIST"
   AC_SUBST([ZEITGEIST_VALAFLAGS])
   ZEITGEIST_PKG="--pkg zeitgeist-2.0"
   AC_SUBST([ZEITGEIST_PKG])
])

# Ignore post 0.20 deprecations
TP_GLIB_CFLAGS="$TP_GLIB_CFLAGS -DTP_VERSION_MIN_REQUIRED=TP_VERSION_0_20"
# Prevent post 0.20 APIs
TP_GLIB_CFLAGS="$TP_GLIB_CFLAGS -DTP_VERSION_MAX_ALLOWED=TP_VERSION_0_20"

AS_IF([test x$enable_tracker_backend = xyes], [
        PKG_CHECK_MODULES([TRACKER_SPARQL],
                          [tracker-sparql-$TRACKER_SPARQL_MAJOR >= \
                           $TRACKER_SPARQL_REQUIRED])
])

AS_IF([test x$enable_eds_backend = xyes], [
        PKG_CHECK_MODULES([EBOOK], [libebook-1.2 >= $EBOOK_REQUIRED
                                    libebook-contacts-1.2 >= $EBOOK_REQUIRED])
        PKG_CHECK_MODULES([EDATASERVER], [libedataserver-1.2 >= $EDATASERVER_REQUIRED])
])

AS_IF([test x$enable_ofono_backend = xyes], [
        PKG_CHECK_MODULES([EBOOK], [libebook-1.2 >= $EBOOK_REQUIRED])
])

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
AS_IF([test \
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
        ! -e ${sd}folks/libfolks_la_vala.stamp \
      ], [
        enable_vala=yes
        echo "Vala source needs to be re-compiled; requiring Vala..."
])

AS_IF([test "x$enable_vala" = "xyes"], [
        AM_PROG_VALAC([$VALA_REQUIRED])
        AS_IF([test "x$VALAC" = "x"], [
              AC_MSG_ERROR([Vala requested but valac is not installed])
        ])

        AC_PATH_PROG([VAPIGEN], [vapigen], [])
        AS_IF([test "x$VAPIGEN" = "x"], [
              AC_MSG_ERROR([Vala must be built with --enable-vapigen])
        ])

        # require GLib >= 2.24 so GLib.Array, etc. reffing is handled
        # automatically
        AM_VALAFLAGS="--target-glib=2.24"
        # within the libfolks tree, select inline code paths
        AM_VALAFLAGS="$AM_VALAFLAGS -D FOLKS_COMPILATION"
        AC_SUBST([AM_VALAFLAGS])
        AC_SUBST([VAPIGENFLAGS])
        AC_SUBST([VAPIDIR])

        VALA_CHECK_PACKAGES([gio-2.0
                             gee-0.8])

        AS_IF([test x$enable_telepathy_backend = xyes], [
          VALA_CHECK_PACKAGES([telepathy-glib])
	  AS_IF([test "x$have_zeitgeist" == "xyes"], [
	      VALA_CHECK_PACKAGES([zeitgeist-2.0])
	  ])
        ])

        AS_IF([test x$enable_tracker_backend = xyes], [
          VALA_CHECK_PACKAGES([tracker-sparql-$TRACKER_SPARQL_MAJOR])
        ])

        AS_IF([test x$enable_eds_backend = xyes], [
          VALA_CHECK_PACKAGES([libebook-1.2 libebook-contacts-1.2 libedataserver-1.2 libxml-2.0])
        ])

        AS_IF([test x$enable_ofono_backend = xyes], [
          VALA_CHECK_PACKAGES([libebook-1.2])
        ])
])

# this will set HAVE_INTROSPECTION
GOBJECT_INTROSPECTION_REQUIRE([1.30])

AM_CONDITIONAL([HAVE_VALA], [test "x$enable_vala" = "xyes"])

# Various functions that we need (used in C code generated from Vala)
AC_CHECK_FUNCS([memset])
AC_CHECK_FUNCS([strstr])

AM_CONDITIONAL([NOT_RELEASE], [test "x$folks_released" = "x0"])

# -----------------------------------------------------------
# Backends
# -----------------------------------------------------------

FOLKS_MODULE_VERSION=folks_module_version
AC_SUBST([FOLKS_MODULE_VERSION])
AC_DEFINE([MODULE_VERSION], "folks_module_version", [Module interface version])

BACKEND_DIR='$(libdir)/folks/$(FOLKS_MODULE_VERSION)/backends'
AC_SUBST([BACKEND_DIR])

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
# Tests
# -----------------------------------------------------------

AC_ARG_ENABLE([tests],
              AS_HELP_STRING([--enable-tests],[Enable building of tests]),
              [enable_tests=$enableval], [enable_tests=yes])
AM_CONDITIONAL([ENABLE_TESTS], [test x$enable_tests = xyes])

# -----------------------------------------------------------
# Documentation
# -----------------------------------------------------------

AC_ARG_ENABLE([docs],
              AS_HELP_STRING([--enable-docs],[Enable documentation generation]),
              [enable_docs=$enableval], [enable_docs=no])
AM_CONDITIONAL([ENABLE_DOCS], [test x$enable_docs = xyes])

have_valadoc=no
AS_IF([test x$enable_docs = xyes], [
  # make sure the library is new enough and the program exists
  PKG_CHECK_MODULES([VALADOC], [valadoc-1.0 >= $VALADOC_REQUIRED])
  AC_PATH_PROG([VALADOC], [valadoc], [:])
  AS_IF([test "$VALADOC" != :], have_valadoc=yes)
])
AM_CONDITIONAL([HAVE_VALADOC], [test x$have_valadoc = xyes])

AS_IF([test "x$enable_docs" = "xyes" -a "x$have_valadoc" != "xyes"], [
    AC_MSG_ERROR([Doc building requested but valadoc not installed.])
])

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

# C_ERROR_CFLAGS are only used for C code from telepathy-glib for now,
# while ERROR_CFLAGS are used for everything.

ERROR_CFLAGS=

AC_ARG_ENABLE([fatal-warnings],
              AS_HELP_STRING([--disable-fatal-warnings],
                             [Make various warnings non-fatal]),
              [enable_fatal_warnings=$enableval], [enable_fatal_warnings=yes])

AC_DEFUN([FOLKS_ADD_WARNING],
  [
    AS_COMPILER_FLAG([-Werror=$2],
      [
        AS_IF([test "x$enable_fatal_warnings" = xyes],
          [$1="[$]$1 -Werror=$2"],
	  [$1="[$]$1 -W$2"])
      ])
  ])

# It isn't 1970 any more. Require that we write proper ISO C with declarations,
# avoiding hard-to-trace bugs on platforms where sizeof(int) != sizeof(void *).
FOLKS_ADD_WARNING([ERROR_CFLAGS], [implicit])
FOLKS_ADD_WARNING([ERROR_CFLAGS], [missing-declarations])
FOLKS_ADD_WARNING([ERROR_CFLAGS], [missing-parameter-type])
FOLKS_ADD_WARNING([ERROR_CFLAGS], [missing-prototypes])
FOLKS_ADD_WARNING([ERROR_CFLAGS], [nested-externs])
FOLKS_ADD_WARNING([ERROR_CFLAGS], [old-style-declaration])
FOLKS_ADD_WARNING([ERROR_CFLAGS], [old-style-definition])
FOLKS_ADD_WARNING([ERROR_CFLAGS], [strict-prototypes])

AS_COMPILER_FLAG([-Wall], [C_ERROR_CFLAGS="-Wall"], [C_ERROR_CFLAGS=""])
AS_COMPILER_FLAG([-Werror], [werror=yes], [werror=no])

AC_ARG_ENABLE([debug],
              AS_HELP_STRING([--disable-debug],[compile without debug code]),
              [enable_debug=$enableval], [enable_debug=yes])

AS_COMPILER_FLAG([-Wextra], [wextra=yes], [wextra=no])
AS_COMPILER_FLAG([-Wno-missing-field-initializers],
                 [wno_missing_field_initializers=yes],
                 [wno_missing_field_initializers=no])
AS_COMPILER_FLAG([-Wno-unused-parameter],
                 [wno_unused_parameter=yes], [wno_unused_parameter=no])
AS_COMPILER_FLAG([-Wstrict-prototypes], [wstrict_prototypes=yes],
                 [wstrict_prototypes=no])
AS_COMPILER_FLAG([-Wmissing-prototypes], [wmissing_prototypes=yes],
                 [wmissing_prototypes=no])
AS_COMPILER_FLAG([-Wimplicit-function-declaration],
                 [wimplicit_function_declaration=yes],
                 [wimplicit_function_declaration=no])
AS_COMPILER_FLAG([-Wpointer-arith], [wpointer_arith=yes], [wpointer_arith=no])
AS_COMPILER_FLAG([-Winit-self], [winit_self=yes], [winit_self=no])
AS_COMPILER_FLAG([-Wformat=2], [wformat=yes], [wformat=no])
AS_COMPILER_FLAG([-Wmissing-include-dirs], [wmissing_include_dirs=yes],
                 [wmissing_include_dirs=no])
AS_COMPILER_FLAG([-Waggregate-return], [waggregate_return=yes],
                 [waggregate_return=no])
AS_COMPILER_FLAG([-Wdeclaration-after-statement],
                 [wdeclaration_after_statement=yes],
                 [wdeclaration_after_statement=no])

m4_if(folks_released, [1], [],
    [
        # Iff we support -Werror, then use it with all our compiler warnings.
        if test x$werror = xyes; then
            flag="-Werror="
        else
            flag="-W"
        fi

        if test x$wextra = xyes -a \
            x$wno_missing_field_initializers = xyes -a \
            x$wno_unused_parameter = xyes -a x$wstrict_prototypes = xyes -a \
            x$wmissing_prototypes = xyes -a \
            x$wimplicit_function_declaration = xyes -a x$wpointer_arith = xyes \
            -a x$winit_self = xyes -a x$wformat = xyes -a \
            x$wmissing_include_dirs = xyes -a x$waggregate_return = xyes -a \
            x$wdeclaration_after_statement = xyes; then
            C_ERROR_CFLAGS="$C_ERROR_CFLAGS -Wextra \
                -Wno-missing-field-initializers \
                -Wno-unused-parameter ${flag}strict-prototypes \
                ${flag}missing-prototypes ${flag}implicit-function-declaration \
                ${flag}pointer-arith ${flag}init-self ${flag}format=2 \
                ${flag}missing-include-dirs ${flag}aggregate-return \
                ${flag}declaration-after-statement"
        fi
    ])

AS_COMPILER_FLAG([-D_POSIX_SOURCE], [C_ERROR_CFLAGS="$C_ERROR_CFLAGS -D_POSIX_SOURCE"])
AS_COMPILER_FLAG([-std=c99], [C_ERROR_CFLAGS="$C_ERROR_CFLAGS -std=c99"])
AS_COMPILER_FLAG([-Wshadow], [C_ERROR_CFLAGS="$C_ERROR_CFLAGS -Wshadow"])
AS_COMPILER_FLAG([-Wmissing-prototypes], [C_ERROR_CFLAGS="$C_ERROR_CFLAGS \
                                          -Wmissing-prototypes"])
AS_COMPILER_FLAG([-Wmissing-declarations], [C_ERROR_CFLAGS="$C_ERROR_CFLAGS \
                                            -Wmissing-declarations"])
AS_COMPILER_FLAG([-Wstrict-prototypes], [C_ERROR_CFLAGS="$C_ERROR_CFLAGS \
                                         -Wstrict-prototypes"])

AC_SUBST([ERROR_CFLAGS])
AC_SUBST([C_ERROR_CFLAGS])

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
# Profiling
# -----------------------------------------------------------

AC_ARG_ENABLE([profiling],
              AS_HELP_STRING([--enable-profiling],
                             [Enable building profiling points]),
              [enable_profiling=$enableval],
              [enable_profiling=no])
AM_CONDITIONAL([ENABLE_PROFILING], [test "$enable_profiling" = "yes"])

# -----------------------------------------------------------
# Final output
# -----------------------------------------------------------

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
    backends/ofono/Makefile
    folks/Makefile
    docs/Makefile
    po/Makefile.in
    tests/Makefile
    tests/data/Makefile
    tests/eds/Makefile
    tests/folks/Makefile
    tests/key-file/Makefile
    tests/libsocialweb/Makefile
    tests/telepathy/Makefile
    tests/tracker/Makefile
    tests/lib/Makefile
    tests/lib/folks-test-uninstalled.pc
    tests/lib/eds/Makefile
    tests/lib/key-file/Makefile
    tests/lib/libsocialweb/Makefile
    tests/lib/telepathy/Makefile
    tests/lib/tracker/Makefile
    tests/lib/telepathy/contactlist/Makefile
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
        Telepathy backend...........:  ${enable_telepathy_backend}
        Tracker backend.............:  ${enable_tracker_backend}
        Libsocialweb backend........:  ${have_libsocialweb_backend}
        E-D-S backend...............:  ${enable_eds_backend}
        Ofono backend...............:  ${enable_ofono_backend}
        Zeitgeist support...........:  ${have_zeitgeist}
        Build tests.................:  ${enable_tests}
"
