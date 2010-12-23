sharedir = $(datadir)/folks

AM_CPPFLAGS = \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DDATA_DIR=\"$(shareddir)\" \
	-DBACKEND_DIR=\"$(BACKEND_DIR)\" \
	-DG_LOG_DOMAIN=\"folks\" \
	$(NULL)

lib_LTLIBRARIES = libfolks.la

# Vala files to compile into libfolks.la
libfolks_la_SOURCES = \
	aliasable.vala \
	backend.vala \
	backend-store.vala \
	favouritable.vala \
	groupable.vala \
	avatar-owner.vala \
	presence-owner.vala \
	imable.vala \
	individual.vala \
	individual-aggregator.vala \
	linked-hash-set.vala \
	persona.vala \
	persona-store.vala \
	types.vala \
	debug.vala \
	$(NULL)

libfolks_la_VALAFLAGS = \
	--vapidir=. \
	--pkg build-conf \
	--pkg gobject-2.0 \
	--pkg gmodule-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--vapi folks.vapi \
	-H folks.h \
	$(NULL)

libfolks_la_CFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GMODULE_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

libfolks_la_LIBADD = \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GMODULE_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

# The quoting here is unnecessary but harmless, and has the useful side-effect
# that vim quickfix mode (:make) doesn't interpret the libtool --mode=link
# command as an error message in a bizarrely named file
libfolks_la_LDFLAGS = \
	-version-info "$(LT_CURRENT)":"$(LT_REVISION)":"$(LT_AGE)"

folksdir = $(includedir)/folks
folks_HEADERS = folks.h

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
	$(NULL)

CLEANFILES = \
	$(pkgconfig_DATA) \
	folks-uninstalled.pc \
	$(NULL)

BUILT_SOURCES = \
	folks.h \
	folks.vapi \
	$(NULL)

GITIGNOREFILES = \
	$(libfolks_la_SOURCES:.vala=.c) \
	libfolks_la_vala.stamp \
	$(NULL)

-include $(top_srcdir)/git.mk
