dnl If not 1, append datestamp to the version number
m4_define(folks_released, 0)

m4_define([folks_major_version], [0])
m4_define([folks_minor_version], [1])
m4_define([folks_micro_version], [6])
m4_define([folks_nano_version], [0])

dnl Display the nano_version only if it's not '0'
m4_define([folks_base_version],
                [folks_major_version.folks_minor_version.folks_micro_version])
m4_define([folks_full_version],
                [m4_if(folks_nano_version, 0, [folks_base_version],
                        [folks_base_version].[folks_nano_version])])

m4_define(folks_maybe_datestamp,
                    m4_esyscmd([if test x]folks_released[ != x1; then date +.%Y%m%d | tr -d '\n\r'; fi]))

m4_define(folks_version, folks_full_version[]folks_maybe_datestamp)


AC_INIT(folks, folks_version, folks)
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])

AC_PREREQ(2.59)
AC_COPYRIGHT([
  Copyright (C) 2010 Collabora Ltd.
])

AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR([Makefile.am])
AC_CONFIG_HEADERS(config.h)
AC_CONFIG_SRCDIR([configure.ac])
AM_INIT_AUTOMAKE(1.9 dist-bzip2 no-define no-dist-gzip tar-ustar -Wno-portability)
AM_MAINTAINER_MODE

AC_PROG_CC
AM_PROG_CC_C_O
AC_DISABLE_STATIC
AC_PROG_LIBTOOL

AC_PATH_PROG(VALAC, valac, valac)
AC_SUBST(VALAC)

AC_SUBST(PKG_CONFIG_PATH)

# require GLib >= 2.24 so GLib.Array, etc. reffing is handled automatically
VALACFLAGS="$VALACFLAGS --target-glib=2.24"
AC_SUBST(VALACFLAGS)
AC_SUBST(VALAFLAGS)

AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_SUBST(LDFLAGS)
GTK_DOC_CHECK([1.10])

GLIB_REQUIRED=2.12.0
TP_GLIB_REQUIRED=0.11.4.1
TP_VALA_REQUIRED=0.11.4.1

PKG_CHECK_MODULES(LIBFOLKS,
                  glib-2.0 >= $GLIB_REQUIRED
                  gobject-2.0 >= $GLIB_REQUIRED
                  dbus-glib-1
                  gee-1.0
                  telepathy-vala >= $TP_VALA_REQUIRED
                  )
AC_SUBST(LIBFOLKS_CFLAGS)
AC_SUBST(LIBFOLKS_LIBS)

# -----------------------------------------------------------
# Documentation
# -----------------------------------------------------------
AC_ARG_ENABLE(docs,
  AC_HELP_STRING([--enable-docs],[Enable documentation generation]),
    enable_docs=$enableval, enable_docs=no)
AM_CONDITIONAL(ENABLE_DOCS, test x$enable_docs = xyes)

AS_IF([test "x$enable_docs" != xno],
  [AC_PATH_PROG(VALADOC, valadoc, :)
   AC_SUBST(VALADOC)
   AS_IF([test "$VALADOC" = :],
     [AC_MSG_ERROR([valadoc not found])])])

# -----------------------------------------------------------
# Telepathy backend
# -----------------------------------------------------------
PKG_CHECK_MODULES(LIBFOLKS_TELEPATHY,
                  glib-2.0 >= $GLIB_REQUIRED
                  gobject-2.0 >= $GLIB_REQUIRED
                  dbus-glib-1
                  gee-1.0
                  telepathy-vala >= $TP_VALA_REQUIRED
                  )
AC_SUBST(LIBFOLKS_TELEPATHY_CFLAGS)
AC_SUBST(LIBFOLKS_TELEPATHY_LIBS)

PKG_CHECK_MODULES(LIBFOLKS_BACKEND_TELEPATHY,
                  glib-2.0 >= $GLIB_REQUIRED
                  gobject-2.0 >= $GLIB_REQUIRED
                  dbus-glib-1
                  gee-1.0
                  telepathy-vala >= $TP_VALA_REQUIRED
                  )
AC_SUBST(LIBFOLKS_BACKEND_TELEPATHY_CFLAGS)
AC_SUBST(LIBFOLKS_BACKEND_TELEPATHY_LIBS)

PKG_CHECK_MODULES(LIBTP_LOWLEVEL,
                  glib-2.0 >= $GLIB_REQUIRED
                  gobject-2.0 >= $GLIB_REQUIRED
                  telepathy-glib >= $TP_GLIB_REQUIRED
                  )
AC_SUBST(LIBTP_LOWLEVEL_CFLAGS)
AC_SUBST(LIBTP_LOWLEVEL_LIBS)

# -----------------------------------------------------------
# Error flags
# -----------------------------------------------------------
AS_COMPILER_FLAG(-Wall, ERROR_CFLAGS="-Wall", ERROR_CFLAGS="")
AS_COMPILER_FLAG(-Werror, werror=yes, werror=no)

AC_ARG_ENABLE(debug,
  AC_HELP_STRING([--disable-debug],[compile without debug code]),
    enable_debug=$enableval, enable_debug=yes)

AC_ARG_ENABLE(Werror,
  AC_HELP_STRING([--disable-Werror],[compile without -Werror (normally enabled in development builds)]),
    werror=$enableval, werror=yes)

AS_COMPILER_FLAG(-Wextra, wextra=yes, wextra=no)
AS_COMPILER_FLAG(-Wno-missing-field-initializers,
        wno_missing_field_initializers=yes,
        wno_missing_field_initializers=no)
AS_COMPILER_FLAG(-Wno-unused-parameter,
        wno_unused_parameter=yes,
        wno_unused_parameter=no)

ifelse(folks_released, 1, [],
    [
        if test x$werror = xyes; then
            ERROR_CFLAGS="$ERROR_CFLAGS -Werror"
        fi
        if test x$wextra = xyes -a \
            x$wno_missing_field_initializers = xyes -a \
            x$wno_unused_parameter = xyes; then
            ERROR_CFLAGS="$ERROR_CFLAGS -Wextra -Wno-missing-field-initializers -Wno-unused-parameter"
        fi
    ])

AS_COMPILER_FLAG(-D_POSIX_SOURCE, ERROR_CFLAGS="$ERROR_CFLAGS -D_POSIX_SOURCE")
AS_COMPILER_FLAG(-std=c99, ERROR_CFLAGS="$ERROR_CFLAGS -std=c99")
AS_COMPILER_FLAG(-Wshadow, ERROR_CFLAGS="$ERROR_CFLAGS -Wshadow")
AS_COMPILER_FLAG(-Wmissing-prototypes, ERROR_CFLAGS="$ERROR_CFLAGS -Wmissing-prototypes")
AS_COMPILER_FLAG(-Wmissing-declarations, ERROR_CFLAGS="$ERROR_CFLAGS -Wmissing-declarations")
AS_COMPILER_FLAG(-Wstrict-prototypes, ERROR_CFLAGS="$ERROR_CFLAGS -Wstrict-prototypes")

AC_SUBST(ERROR_CFLAGS)

# -----------------------------------------------------------
# Final output
# -----------------------------------------------------------

AC_CONFIG_FILES([
	backends/telepathy/folks-telepathy.pc
	backends/telepathy/folks-telepathy-uninstalled.pc
	folks/folks.pc
	folks/folks-uninstalled.pc
	Makefile
	backends/Makefile
	backends/telepathy/Makefile
	folks/Makefile
	docs/Makefile
])

AC_OUTPUT

echo "
Configure summary:

        Compiler....................:  ${VALAC}
        Compiler Flags..............:  ${CFLAGS} ${ERROR_CFLAGS}
        Prefix......................:  ${prefix}
        Coding style checks.........:  ${ENABLE_CODING_STYLE_CHECKS}
        VAPI generation.............:  ${enable_vapigen}
        Bugreporting URL............:  ${PACKAGE_BUGREPORT}
        Documentation...............:  ${enable_docs}


"
