GEN_INTROSPECT = $(shell pkg-config vala-1.0 --variable="gen_introspect")
VAPIGEN = $(shell pkg-config vala-1.0 --variable="vapigen")

AM_CPPFLAGS = \
	$(LIBFOLKS_BACKEND_TELEPATHY_CFLAGS) \
	$(LIBFOLKS_CFLAGS) \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	$(NULL)

# this seems to work, even if vim's syntax highlighting suggests otherwise
VALAFLAGS += $(shell PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) pkg-config --variable=valaflags telepathy-vala)
VALAFLAGS += --vapidir=. --vapidir=$(top_srcdir)/folks

VALAFLAGS += \
	--pkg build-conf \
	--pkg folks \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--pkg gmodule-2.0 \
	--pkg dbus-glib-1 \
	--pkg telepathy-glib \
	$(NULL)

backenddir = $(libdir)/folks/backends/telepathy
backend_LTLIBRARIES = libfolks-backend-telepathy.la
noinst_LTLIBRARIES = liblowlevel.la

liblowlevel_la_SOURCES = \
	lowlevel.c \
	lowlevel.h \
	$(NULL)

liblowlevel_la_CPPFLAGS = \
	$(LIBLOWLEVEL_CFLAGS) \
	$(NULL)

# the -shared and -rpath arguments are to force it to be compiled to a .so,
# despite not being installed (it needs to be a shared library for
# vala-gen-introspect)
liblowlevel_la_LDFLAGS = \
	-shared -rpath $(backenddir) \
	$(LIBLOWLEVEL_LIBS) \
	$(NULL)

lowlevel.gi: $(liblowlevel_la_SOURCES) liblowlevel.la
	$(VGI_V)$(GEN_INTROSPECT) --namespace=Folks lowlevel.h \
		$(shell pkg-config telepathy-glib --cflags) \
		.libs/liblowlevel.so > lowlevel.gi

lowlevel.vapi: lowlevel.gi lowlevel.metadata
	$(VAPIGEN_V)$(VAPIGEN) $(VALAFLAGS) --library lowlevel \
		--metadata=lowlevel.metadata \
		lowlevel.gi

internal_vapi_files = \
	lowlevel.vapi \
	$(NULL)

libfolks_backend_telepathy_la_VALASOURCES = \
	tp-backend.vala \
	tp-backend-factory.vala \
	tp-persona.vala \
	tp-persona-store.vala \
	$(NULL)

libfolks_backend_telepathy_la_SOURCES = \
	folks-backend-telepathy.vala.stamp \
	$(libfolks_backend_telepathy_la_VALASOURCES:.vala=.c) \
	$(liblowlevel_la_SOURCES) \
	$(NULL)

libfolks_backend_telepathy_la_LIBADD = \
	$(LIBFOLKS_BACKEND_TELEPATHY_LIBS) \
	$(LIBFOLKS_LIBS) \
	$(NULL)

libfolks_backend_telepathy_la_LDFLAGS = -shared -fPIC -module -avoid-version

backend_includedir = $(includedir)/folks
backend_include_HEADERS = \
	folks-backend-telepathy.h \
	$(NULL)

folks_backend_telepathy_stamp_targets = \
	folks-backend-telepathy.h \
	$(libfolks_backend_telepathy_la_VALASOURCES:.vala=.c) \
	$(libfolks_backend_telepathy_la_VALASOURCES:.vala=.h) \
	$(NULL)

$(folks_backend_telepathy_stamp_targets): folks-backend-telepathy.vala.stamp

vapi_deps = \
	$(libfolks_backend_telepathy_la_VALASOURCES) \
	$(internal_vapi_files) \
	$(NULL)

folks-backend-telepathy.vapi folks-backend-telepathy.vala.stamp: $(vapi_deps)
	$(VALA_V)$(VALAC) $(VALAFLAGS) -H folks-backend-telepathy.h -C \
		--library folks-backend-telepathy \
		--pkg lowlevel \
		$(libfolks_backend_telepathy_la_VALASOURCES)
	touch $@

pkgconfig_in = folks-backend-telepathy.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

BUILT_SOURCES = \
	folks-backend-telepathy.h \
	folks-backend-telepathy.vala.stamp \
	folks-backend-telepathy.vapi \
	lowlevel.gi \
	lowlevel.vapi \
	$(libfolks_backend_telepathy_la_VALASOURCES:.vala=.c) \
	$(pkgconfig_in:.in=) \
	folks-backend-telepathy-uninstalled.pc \
	$(NULL)

CLEANFILES = $(BUILT_SOURCES)

EXTRA_DIST = \
	$(pkgconfig_in) \
	folks-backend-telepathy.vala.stamp \
	folks-backend-telepathy.vapi \
	lowlevel.vapi \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(libfolks_backend_telepathy_la_VALASOURCES:.vala=.c) \
	$(NULL)

# set up the verbosity rules to avoid some build noise
# XXX: once automake >= 1.11 is common, remove these, push VALASOURCES files
# into SOURCES and add AM_PROG_VALAC to configure.ac
VALA_V = $(VALA_V_$(V))
VALA_V_ = $(VALA_V_$(AM_DEFAULT_VERBOSITY))
VALA_V_0 = @echo "  VALAC " $^;

VAPIGEN_V = $(VAPIGEN_V_$(V))
VAPIGEN_V_ = $(VAPIGEN_V_$(AM_DEFAULT_VERBOSITY))
VAPIGEN_V_0 = @echo "  VAPIG " $^;

VGI_V = $(VGI_V_$(V))
VGI_V_ = $(VGI_V_$(AM_DEFAULT_VERBOSITY))
VGI_V_0 = @echo "  VGI   " $^;
