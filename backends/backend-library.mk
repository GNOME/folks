#
# Common build variable values for folks backend libraries.
#
# Required variables:
#  - BACKEND_NAME = name-of-backend
#    (this must be the same as the source directory and the backend's type ID)
#  - BACKEND_NAME_C = NameOfBackend
#    (BACKEND_NAME in CamelCase for the GIR filename)
#  - BACKEND_API_VERSION = $(FOLKS_something_API_VERSION)
#  - BACKEND_LT_VERSION = $(FOLKS_something_LT_VERSION)
#    (from configure.ac)
#  - BACKEND_SYMBOLS_REGEX = something
#    (regex to pass to -export-symbols-regex to determine the backend’s public
#     symbols)
#  - BACKEND_NAMESPACE = Something
#    (Vala namespace used in the backend code)
# Required targets:
#  - libfolks-$(BACKEND_NAME).la
# Derived helper variables (these may be overridden for weird backends):
#  - BACKEND_LIBRARY_NAME
#  - BACKEND_LA_FILE
#  - BACKEND_PC_FILE
#  - BACKEND_GIR_FILE
#  - BACKEND_VAPI_FILE
#  - BACKEND_DEPS_FILE
#  - BACKEND_HEADER_FILE
# Defined backend library variables (these must be included in the
# backend-specific variables):
#  - backend_library_sources
#  - backend_library_valaflags
#  - backend_library_cppflags
#  - backend_library_cflags
#  - backend_library_libadd
#  - backend_library_ldflags
# in addition, most of these have *_generic variants which don’t include
# backend-specific flags (for use in helper and utility libraries).
# The defined variables include flags for the standard dependencies:
#  - folks
#  - GIO
#  - GLib
#  - libgee
# and also include the relevant $(AM_*) variables.
#
# Additional rules are included for generating and installing the following:
#  - pkg-config
#  - VAPI and deps files
#  - C header file
#  - GIR and typelib files

# Derived (but still overrideable) variables
BACKEND_LIBRARY_NAME = folks-$(BACKEND_NAME)
BACKEND_LA_FILE = lib$(BACKEND_LIBRARY_NAME).la
BACKEND_PC_FILE = $(BACKEND_LIBRARY_NAME).pc.in
BACKEND_GIR_FILE = Folks$(BACKEND_NAME_C)-$(BACKEND_API_VERSION).gir
BACKEND_VAPI_FILE = $(BACKEND_LIBRARY_NAME).vapi
BACKEND_DEPS_FILE = $(BACKEND_LIBRARY_NAME).deps
BACKEND_HEADER_FILE = folks/$(BACKEND_LIBRARY_NAME).h


# Added in case it's needed in the future.
backend_library_sources = \
	namespace.vala \
	$(NULL)

backend_library_cppflags_generic = \
	$(AM_CPPFLAGS) \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-include $(top_srcdir)/folks/warnings.h \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	$(NULL)
backend_library_cppflags = \
	$(backend_library_cppflags_generic) \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

backend_library_valaflags_generic = \
	$(AM_VALAFLAGS) \
	$(TARGET_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_builddir)/folks \
	--pkg build-conf \
	--pkg folks \
	--pkg folks-internal \
	--pkg folks-generics \
	--pkg gee-0.8 \
	--pkg gio-2.0 \
	--pkg gobject-2.0 \
	$(NULL)
backend_library_valaflags = \
	$(backend_library_valaflags_generic) \
	--includedir folks \
	--gir $(BACKEND_GIR_FILE) \
	--library $(BACKEND_LIBRARY_NAME) \
	--vapi $(BACKEND_VAPI_FILE) \
	-H $(BACKEND_HEADER_FILE) \
	$(NULL)

backend_library_cflags_generic = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)
backend_library_cflags = $(backend_library_cflags_generic)

backend_library_libadd_generic = \
	$(AM_LIBADD) \
	$(top_builddir)/folks/libfolks.la \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(NULL)
backend_library_libadd = \
	$(backend_library_libadd_generic) \
	$(NULL)

backend_library_ldflags_generic = \
	$(AM_LDFLAGS) \
	$(CODE_COVERAGE_LDFLAGS) \
	-no-undefined \
	$(NULL)
backend_library_ldflags = \
	$(backend_library_ldflags_generic) \
	-version-info $(BACKEND_LT_VERSION) \
	-export-symbols-regex $(BACKEND_SYMBOLS_REGEX) \
	$(NULL)


# Namespace Vala file
#
# FIXME: This can be removed once the backend namespaces have been sanitised.
# https://bugzilla.gnome.org/show_bug.cgi?id=711544
#
# This file sets namespace and version attributes for GIR.
namespace.vala:
	$(AM_V_GEN)echo -e "[CCode (gir_namespace = \"Folks$(BACKEND_NAME_C)\", gir_version = \"$(BACKEND_API_VERSION)\")]\nnamespace $(BACKEND_NAMESPACE) {}" > $(srcdir)/$@

MAINTAINERCLEANFILES += namespace.vala

# Installed headers
folks_includedir = $(includedir)/folks
folks_include_HEADERS = $(BACKEND_HEADER_FILE)

vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = \
	$(BACKEND_VAPI_FILE) \
	$(BACKEND_DEPS_FILE) \
	$(NULL)


# pkg-config
pkgconfig_in = $(BACKEND_PC_FILE)
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)
EXTRA_DIST += $(pkgconfig_in)


# Introspection
-include $(INTROSPECTION_MAKEFILE)
INTROSPECTION_SCANNER_ARGS = \
	$(ERROR_INTROSPECTION_SCANNER_ARGS) \
	--add-include-path=$(srcdir) \
	--add-include-path=$(builddir) \
	--add-include-path=$(abs_top_srcdir)/folks \
	--add-include-path=$(abs_top_builddir)/folks \
	--warn-all \
	$(NULL)

# Set PKG_CONFIG_PATH so we can find the backend's uninstalled pkg-config file.
INTROSPECTION_SCANNER_ENV = \
	PKG_CONFIG_PATH=$(top_builddir)/folks:$${PKG_CONFIG_PATH}

INTROSPECTION_COMPILER_ARGS = \
	--includedir=$(srcdir) \
	--includedir=$(builddir) \
	--includedir=$(abs_top_srcdir)/folks \
	--includedir=$(abs_top_builddir)/folks \
	$(NULL)

if HAVE_INTROSPECTION
$(BACKEND_GIR_FILE): $(BACKEND_LA_FILE)
GIRS = $(BACKEND_GIR_FILE)

girdir = $(datadir)/gir-1.0
dist_gir_DATA = $(GIRS)

MAINTAINERCLEANFILES += $(dist_gir_DATA)

typelibdir = $(libdir)/girepository-1.0
nodist_typelib_DATA = $(GIRS:.gir=.typelib)

CLEANFILES += $(nodist_typelib_DATA)
endif
