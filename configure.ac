# If not 1, append datestamp to the version number
m4_define([folks_released], [0])

m4_define([folks_major_version], [0])
m4_define([folks_minor_version], [1])
m4_define([folks_micro_version], [18])
m4_define([folks_nano_version], [0])

# If library source has changed since last release, increment revision
# If interfaces have been added, removed or changed since last release,
#  increment current and set revision to 0
# If interfaces have been added since last release, increment age
# If interfaces have been removed since last release, set age to 0
m4_define([folks_lt_current], [14])
m4_define([folks_lt_revision], [0])
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
AM_INIT_AUTOMAKE([1.11 dist-bzip2 no-define
                  no-dist-gzip tar-ustar -Wno-portability])
AM_MAINTAINER_MODE

AC_PROG_CC
AM_PROG_CC_C_O
AC_DISABLE_STATIC
LT_INIT
PKG_PROG_PKG_CONFIG([0.21])

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

# -----------------------------------------------------------
# Dependencies
# -----------------------------------------------------------

GLIB_REQUIRED=2.24.0
TP_GLIB_REQUIRED=0.11.11
# FIXME: remove the machinery using this once it's safe to require this version
# (be sure to remove the HAVE_TP_GLIB_FOR_TESTS conditionals in Makefile.am
# files)
TP_GLIB_TESTS_REQUIRED=0.11.14.1
VALA_REQUIRED=0.9.6

AM_PROG_VALAC([$VALA_REQUIRED])

# require GLib >= 2.24 so GLib.Array, etc. reffing is handled automatically
VALACFLAGS="$VALACFLAGS --target-glib=2.24"
AC_SUBST([VALACFLAGS])
AC_SUBST([VALAFLAGS])
AC_SUBST([VAPIDIR])

AC_PATH_PROG([VAPIGEN], [vapigen], [vapigen])
AS_IF([test "$VAPIGEN" = ""],
      [AC_MSG_ERROR([Vala must be built with --enable-vapigen])])

GOBJECT_INTROSPECTION_REQUIRE([0.6.7])

PKG_CHECK_MODULES([GLIB],
                  [glib-2.0 >= $GLIB_REQUIRED
                   gobject-2.0 >= $GLIB_REQUIRED])
PKG_CHECK_MODULES([GIO], [gio-2.0 >= $GLIB_REQUIRED])
PKG_CHECK_MODULES([DBUS_GLIB], [dbus-glib-1])

# FIXME: We depend on libgee < 0.7 because 0.7 breaks API. bgo#627746
PKG_CHECK_MODULES([GEE], [gee-1.0 < 0.7])
PKG_CHECK_MODULES([TP_GLIB], [telepathy-glib >= $TP_GLIB_REQUIRED])
VALA_CHECK_PACKAGES([telepathy-glib
                     dbus-glib-1
                     gio-2.0
                     gee-1.0])

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

# -----------------------------------------------------------
# Tests
# -----------------------------------------------------------

PKG_CHECK_MODULES([TP_GLIB_FOR_TESTS],
                  [telepathy-glib >= $TP_GLIB_TESTS_REQUIRED],
                  [have_tp_glib_for_tests=true], [have_tp_glib_for_tests=false])
AM_CONDITIONAL([HAVE_TP_GLIB_FOR_TESTS], [$have_tp_glib_for_tests])

# -----------------------------------------------------------
# Tools
# -----------------------------------------------------------

PKG_CHECK_MODULES(LIBXML, libxml-2.0, [have_libxml=yes], [have_libxml=no])
AM_CONDITIONAL([HAVE_LIBXML], [test "$have_libxml" = "yes"])

# -----------------------------------------------------------
# Documentation
# -----------------------------------------------------------

AC_ARG_ENABLE([docs],
              AS_HELP_STRING([--enable-docs],[Enable documentation generation]),
              [enable_docs=$enableval], [enable_docs=no])
AM_CONDITIONAL([ENABLE_DOCS], [test x$enable_docs = xyes])

AS_IF([test "x$enable_docs" != xno],
      [AC_PATH_PROG([VALADOC], [valadoc], [:])
       AS_IF([test "$VALADOC" = :],
             [AC_MSG_ERROR([valadoc not found])])])

# -----------------------------------------------------------
# Error flags
# -----------------------------------------------------------

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
# Final output
# -----------------------------------------------------------

AC_CONFIG_FILES([
    backends/telepathy/lib/folks-telepathy.pc
    backends/telepathy/lib/folks-telepathy-uninstalled.pc
    folks/folks.pc
    folks/folks-uninstalled.pc
    Makefile
    backends/Makefile
    backends/key-file/Makefile
    backends/telepathy/Makefile
    backends/telepathy/lib/Makefile
    folks/Makefile
    docs/Makefile
    tests/Makefile
    tests/telepathy/Makefile
    tests/lib/Makefile
    tests/lib/telepathy/Makefile
    tests/lib/telepathy/contactlist/Makefile
    tests/lib/telepathy/contactlist/session.conf
    tests/tools/Makefile
    tools/Makefile
])

AC_OUTPUT

echo "
Configure summary:

        Compiler....................:  ${VALAC}
        Compiler Flags..............:  ${CFLAGS} ${ERROR_CFLAGS}
        Prefix......................:  ${prefix}
        Bugreporting URL............:  ${PACKAGE_BUGREPORT}
        Documentation...............:  ${enable_docs}
        Tests.......................:  ${have_tp_glib_for_tests}
        Import tool.................:  ${have_libxml}


"
