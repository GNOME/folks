CLEANFILES =
MAINTAINERCLEANFILES =
EXTRA_DIST =

include $(top_srcdir)/backends/backend-library.mk

BACKEND_NAME = telepathy
BACKEND_NAME_C = Telepathy
BACKEND_LT_VERSION = $(FOLKS_TELEPATHY_LT_VERSION)
BACKEND_API_VERSION = $(FOLKS_TELEPATHY_API_VERSION)
BACKEND_SYMBOLS_REGEX = "^tpf_.*"
BACKEND_NAMESPACE = Tpf

VAPIGENFLAGS = \
	--vapidir=$(abs_builddir) \
	--vapidir=$(abs_srcdir) \
	--vapidir=$(abs_top_builddir)/folks \
	--vapidir=$(abs_top_srcdir)/folks \
	$(NULL)

noinst_LTLIBRARIES = libtp-lowlevel.la
lib_LTLIBRARIES = libfolks-telepathy.la

if ENABLE_ZEITGEIST
noinst_LTLIBRARIES += libtp-zeitgeist.la
else
noinst_LTLIBRARIES += libtp-zeitgeist-dummy.la
endif

# Necessary because they're only conditionally listed in noinst_LTLIBRARIES.
CLEANFILES += \
	libtp-zeitgeist.la \
	libtp-zeitgeist-dummy.la \
	$(NULL)

dist_noinst_DATA =

##################################################################
# Telepathy Lowlevel library
##################################################################

libtp_lowlevel_la_SOURCES = \
	tp-lowlevel.c \
	$(NULL)

tp_lowlevel_headers = tp-lowlevel.h

libtp_lowlevel_la_CFLAGS = \
	$(backend_library_cflags_generic) \
	$(C_ERROR_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	$(NULL)

# the -shared and -rpath arguments are to force it to be compiled to a .so,
# despite not being installed (it needs to be a shared library for
# vala-gen-introspect)
libtp_lowlevel_la_LDFLAGS = \
	$(backend_library_ldflags_generic) \
	-shared \
	-rpath $(libdir) \
	-avoid-version \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(TP_GLIB_LIBS) \
	$(NULL)

if HAVE_VALA
tp-lowlevel.vapi: TpLowlevel-$(API_VERSION_DOT).gir
	$(MAKE) $(AM_MAKEFLAGS) TpLowlevel-$(API_VERSION_DOT).gir
	$(AM_V_GEN)$(VAPIGEN) $(VAPIGENFLAGS) \
		--library tp-lowlevel \
		--pkg gio-2.0 \
		--pkg telepathy-glib \
		TpLowlevel-$(API_VERSION_DOT).gir
	touch $@
endif

dist_noinst_DATA += tp-lowlevel.vapi

##################################################################
# Zeitgeist shim libraries
#
# Two libraries with identical interfaces, one (libtp-zeitgeist.la) which links
# to Zeitgeist, and one (libtp-zeitgeist-dummy.la) which does not (and uses
# no-ops for all methods). C code for both is always generated, but the former
# is only compiled if Zeitgeist is available. One is always linked into
# libfolks-telepathy.la, depending on whether Zeitgeist support is enabled.
#
# These fun and games are necessary because Vala won't pass #if conditionals
# through to generated C code (with good reason).
#
# See https://bugzilla.gnome.org/show_bug.cgi?id=701099.
##################################################################

libtp_zeitgeist_la_SOURCES = tp-zeitgeist.vala
libtp_zeitgeist_dummy_la_SOURCES = tp-zeitgeist-dummy.vala

libtp_zeitgeist_la_CFLAGS = \
	$(backend_library_cflags_generic) \
	$(TP_GLIB_CFLAGS) \
	$(ZEITGEIST_CFLAGS) \
	$(NULL)
libtp_zeitgeist_dummy_la_CFLAGS = \
	$(backend_library_cflags_generic) \
	$(TP_GLIB_CFLAGS) \
	$(NULL)

libtp_zeitgeist_la_CPPFLAGS = \
	$(backend_library_cppflags_generic) \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	-DABS_TOP_SRCDIR=\"${abs_top_srcdir}\" \
	-DABS_TOP_BUILDDIR=\"${abs_top_builddir}\" \
	-DPKGLIBEXECDIR=\"${pkglibexecdir}\" \
	$(NULL)
libtp_zeitgeist_dummy_la_CPPFLAGS = $(libtp_zeitgeist_la_CPPFLAGS)

libtp_zeitgeist_la_LIBADD = \
	$(backend_library_libadd_generic) \
	$(TP_GLIB_LIBS) \
	$(ZEITGEIST_LIBS) \
	$(NULL)
libtp_zeitgeist_dummy_la_LIBADD = \
	$(backend_library_libadd_generic) \
	$(TP_GLIB_LIBS) \
	$(NULL)

libtp_zeitgeist_la_VALAFLAGS = \
	$(backend_library_valaflags_generic) \
	--pkg zeitgeist-2.0 \
	--pkg telepathy-glib \
	--library tp-zeitgeist \
	--vapi tp-zeitgeist.vapi \
	-H tp-zeitgeist.h \
	$(NULL)
libtp_zeitgeist_dummy_la_VALAFLAGS = \
	$(backend_library_valaflags_generic) \
	--pkg telepathy-glib \
	--library tp-zeitgeist-dummy \
	--vapi tp-zeitgeist-dummy.vapi \
	-H tp-zeitgeist-dummy.h \
	$(NULL)


if ENABLE_ZEITGEIST
dist_noinst_DATA += tp-zeitgeist.vapi
else
dist_noinst_DATA += tp-zeitgeist-dummy.vapi
endif

##################################################################
# Support library
##################################################################

FOLKS_TP_VALA_DEPS = tp-lowlevel.vapi
if ENABLE_ZEITGEIST
FOLKS_TP_VALA_DEPS += tp-zeitgeist.vapi
else
FOLKS_TP_VALA_DEPS += tp-zeitgeist-dummy.vapi
endif
BUILT_SOURCES = $(FOLKS_TP_VALA_DEPS)

libfolks_telepathy_la_SOURCES = \
	$(backend_library_sources) \
	tpf-persona.vala \
	tpf-persona-store.vala \
	tpf-logger.vala \
	tpf-persona-store-cache.vala \
	tp-lowlevel.c \
	$(NULL)

libfolks_telepathy_la_VALAFLAGS = \
	$(backend_library_valaflags) \
	--vapidir=$(abs_builddir) \
	--pkg tp-lowlevel \
	--pkg telepathy-glib \
	$(NULL)

if ENABLE_ZEITGEIST
libfolks_telepathy_la_VALAFLAGS += --pkg tp-zeitgeist
else
libfolks_telepathy_la_VALAFLAGS += --pkg tp-zeitgeist-dummy
endif

libfolks_telepathy_la_CPPFLAGS = \
	$(backend_library_cppflags) \
	$(NULL)

libfolks_telepathy_la_CFLAGS = \
	$(backend_library_cflags) \
	$(TP_GLIB_CFLAGS) \
	$(NULL)

libfolks_telepathy_la_LIBADD = \
	$(backend_library_libadd) \
	$(TP_GLIB_LIBS) \
	$(NULL)

if ENABLE_ZEITGEIST
libfolks_telepathy_la_LIBADD += libtp-zeitgeist.la
else
libfolks_telepathy_la_LIBADD += libtp-zeitgeist-dummy.la
endif

libfolks_telepathy_la_LDFLAGS = \
	$(backend_library_ldflags) \
	$(NULL)

##################################################################
# General
##################################################################

if NOT_RELEASE
DISTCLEANFILES = $(dist_noinst_DATA)
endif

EXTRA_DIST += \
	$(libtp_lowlevel_la_SOURCES) \
	$(NULL)

# XXX: headers separated because automake erroneously treats all libraries in
# this file as Vala-based, so it will try (and fail) to compile the header into
# a Vala library during distcheck otherwise
noinst_HEADERS = $(tp_lowlevel_headers)

##################################################################
# Introspection
##################################################################

INTROSPECTION_GIRS =
DISTCHECK_CONFIGURE_FLAGS = --enable-introspection

#------------------------------------
# TpLowlevel
#------------------------------------
TpLowlevel_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_INCLUDES = GObject-2.0 TelepathyGLib-0.12
TpLowlevel_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_CFLAGS = $(TP_GLIB_CFLAGS)
TpLowlevel_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_LIBS = libtp-lowlevel.la
TpLowlevel_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_FILES = $(libtp_lowlevel_la_SOURCES) $(tp_lowlevel_headers)
TpLowlevel_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_NAMESPACE = TpLowlevel
TpLowlevel_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_SCANNERFLAGS = \
	--identifier-prefix=FolksTpLowlevel \
	--c-include="tp-lowlevel.h" \
	$(NULL)
TpLowlevel_@API_VERSION_MAJOR@_@API_VERSION_MINOR@_gir_VERSION = $(API_VERSION_DOT)
INTROSPECTION_GIRS += TpLowlevel-$(API_VERSION_DOT).gir
dist_noinst_DATA += \
	TpLowlevel-$(API_VERSION_DOT).gir \
	TpLowlevel-$(API_VERSION_DOT).typelib \
	$(NULL)

TpLowlevel-$(API_VERSION_DOT).gir: libtp-lowlevel.la

MAINTAINERCLEANFILES += TpLowlevel-$(API_VERSION_DOT).gir
CLEANFILES += TpLowlevel-$(API_VERSION_DOT).typelib

##################################################################
# Common
##################################################################

-include $(top_srcdir)/git.mk
