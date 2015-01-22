AM_CPPFLAGS = \
	-I${top_srcdir} \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_DIR=\"$(BACKEND_DIR)\" \
	-DG_LOG_DOMAIN=\"folks\" \
	$(NULL)

noinst_LTLIBRARIES = libfolks-internal.la
lib_LTLIBRARIES = libfolks.la

##################################################
# Internal library
##################################################

libfolks_internal_la_SOURCES = \
	folks-generics.vapi \
	internal.vala \
	small-set.c \
	small-set.h \
	small-set-internal.h \
	$(NULL)

libfolks_internal_la_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	$(TARGET_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--library=folks-internal \
	--vapidir=$(abs_srcdir) \
	--vapidir=$(abs_builddir) \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg posix \
	--vapi folks-internal.vapi \
	-H folks-internal.h \
	$(NULL)
if ENABLE_PROFILING
libfolks_internal_la_VALAFLAGS += --define=ENABLE_PROFILING
endif

libfolks_internal_la_CPPFLAGS = \
	$(AM_CPPFLAGS) \
	-include $(top_srcdir)/folks/warnings.h \
	$(NULL)

libfolks_internal_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

libfolks_internal_la_LDFLAGS = \
	$(AM_LDFLAGS) \
	$(CODE_COVERAGE_LDFLAGS) \
	-no-undefined \
	$(NULL)

libfolks_internal_la_LIBADD = \
	$(AM_LIBADD) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

##################################################
# Core library
##################################################

libfolks_la_vala.stamp: folks-internal.vapi

libfolks_la_SOURCES = \
	abstract-field-details.vala \
	alias-details.vala \
	avatar-details.vala \
	backend.vala \
	backend-store.vala \
	birthday-details.vala \
	email-details.vala \
	extended-info.vala \
	favourite-details.vala \
	folks-namespace.vala \
	gender-details.vala \
	group-details.vala \
	web-service-details.vala \
	im-details.vala \
	interaction-details.vala \
	local-id-details.vala \
	location-details.vala \
	name-details.vala \
	note-details.vala \
	phone-details.vala \
	postal-address-details.vala \
	presence-details.vala \
	role-details.vala \
	url-details.vala \
	individual.vala \
	individual-aggregator.vala \
	persona.vala \
	persona-store.vala \
	types.vala \
	debug.vala \
	utils.vala \
	potential-match.vala \
	avatar-cache.vala \
	object-cache.vala \
	anti-linkable.vala \
	query.vala \
	search-view.vala \
	simple-query.vala \
	$(NULL)

if ENABLE_EDS
EDS_FLAGS = -D ENABLE_EDS
endif

libfolks_la_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	$(TARGET_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--gir=Folks-$(API_VERSION_DOT).gir \
	--library=folks \
	--vapidir=$(abs_srcdir) \
	--vapidir=$(abs_builddir) \
	--pkg build-conf \
	--pkg folks-internal \
	--pkg folks-generics \
	--pkg gobject-2.0 \
	--pkg gmodule-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--includedir folks \
	--vapi folks.vapi \
	-H folks.h \
	$(EDS_FLAGS) \
	$(NULL)

libfolks_la_CPPFLAGS = \
	$(AM_CPPFLAGS) \
	-include $(top_srcdir)/folks/warnings.h \
	$(NULL)

libfolks_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GMODULE_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

libfolks_la_LIBADD = \
	$(AM_LIBADD) \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GMODULE_LIBS) \
	$(GEE_LIBS) \
	libfolks-internal.la \
	$(NULL)

# The quoting here is unnecessary but harmless, and has the useful side-effect
# that vim quickfix mode (:make) doesn't interpret the libtool --mode=link
# command as an error message in a bizarrely named file
libfolks_la_LDFLAGS = \
	$(AM_LDFLAGS) \
	$(CODE_COVERAGE_LDFLAGS) \
	-version-info "$(LT_CURRENT)":"$(LT_REVISION)":"$(LT_AGE)" \
	-no-undefined \
	$(NULL)

folksdir = $(includedir)/folks
folks_HEADERS = folks.h

dist_noinst_DATA = \
	folks-internal.vapi \
	$(NULL)

vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = \
	folks.vapi \
	folks.deps \
	$(NULL)

pkgconfig_in = folks.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

EXTRA_DIST = \
	$(pkgconfig_in) \
	build-conf.vapi \
	redeclare-internal-api.h \
	warnings.h \
	$(NULL)

CLEANFILES =
MAINTAINERCLEANFILES =

# We have to extract our own dlname from libfolks.la; see bgo#658002.
# This is what g-ir-scanner does.
libfolks_dlname = \
	`$(SED) -n "s/^dlname='\([A-Za-z0-9.+-]\+\)'/\1/p" libfolks.la`

-include $(INTROSPECTION_MAKEFILE)
INTROSPECTION_GIRS =
INTROSPECTION_SCANNER_ARGS =
INTROSPECTION_COMPILER_ARGS = -l $(libfolks_dlname)

# Set PKG_CONFIG_PATH so we can find the backend's uninstalled pkg-config file.
INTROSPECTION_SCANNER_ENV = \
	PKG_CONFIG_PATH=$(top_builddir)/folks:$${PKG_CONFIG_PATH}

if HAVE_INTROSPECTION
Folks-$(API_VERSION_DOT).gir: libfolks.la
GIRS = Folks-$(API_VERSION_DOT).gir

girdir = $(datadir)/gir-1.0
dist_gir_DATA = $(GIRS)

MAINTAINERCLEANFILES += $(dist_gir_DATA)

typelibdir = $(libdir)/girepository-1.0
nodist_typelib_DATA = $(GIRS:.gir=.typelib)

CLEANFILES += $(nodist_typelib_DATA)
endif

##################################################
# GSettings
##################################################

gsettings_SCHEMAS = org.freedesktop.folks.gschema.xml

@GSETTINGS_RULES@

# Data migration tool
convertdir = $(datadir)/GConf/gsettings
convert_DATA = folks.convert

EXTRA_DIST += $(convert_DATA)
CLEANFILES += $(gsettings_SCHEMAS)
GITIGNOREFILES = org.freedesktop.folks.gschema.valid

-include $(top_srcdir)/git.mk
