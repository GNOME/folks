sharedir = $(datadir)/folks

AM_CPPFLAGS = \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DDATA_DIR=\"$(shareddir)\" \
	-DBACKEND_DIR=\"$(BACKEND_DIR)\" \
	-DG_LOG_DOMAIN=\"Core\" \
	$(NULL)

lib_LTLIBRARIES = libfolks.la

# Vala files to compile into libfolks.la
folks_valasources = \
	aliasable.vala \
	avatar.vala \
	backend.vala \
	backend-store.vala \
	favourite.vala \
	groupable.vala \
	imable.vala \
	individual.vala \
	individual-aggregator.vala \
	persona.vala \
	persona-store.vala \
	presence.vala \
	types.vala \
	debug.vala \
	$(NULL)

libfolks_la_SOURCES = $(folks_valasources:.vala=.c)

# Build-time dependencies for libfolks
folks_deps = \
	build-conf \
	gobject-2.0 \
	gmodule-2.0 \
	gio-2.0 \
	gee-1.0 \
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

folks.h $(libfolks_la_SOURCES): folks.vala.stamp

folks.vapi folks.vala.stamp: $(folks_valasources)
	$(VALA_V)$(VALAC) $(VALAFLAGS) -C -H folks.h \
		--library folks --vapidir=. $(addprefix --pkg ,$(folks_deps)) \
		$(folks_valasources)
	touch $@

vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = \
	folks.vapi \
	folks.deps \
	$(NULL)

pkgconfig_in = folks.pc.in
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = $(pkgconfig_in:.in=)

EXTRA_DIST = \
	$(folks_valasources) \
	$(pkgconfig_in) \
	build-conf.vapi \
	folks.vala.stamp \
	folks.vapi \
	$(NULL)

CLEANFILES = \
	folks.h \
	$(libfolks_la_SOURCES) \
	folks.vapi \
	folks.vala.stamp \
	$(pkgconfig_DATA) \
	folks-uninstalled.pc \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(libfolks_la_SOURCES) \
	$(NULL)

# set up the verbosity rules to avoid some build noise
# XXX: once automake >= 1.11 is common, remove these, push folks_valasources
# files into SOURCES and add AM_PROG_VALAC to configure.ac
VALA_V = $(VALA_V_$(V))
VALA_V_ = $(VALA_V_$(AM_DEFAULT_VERBOSITY))
VALA_V_0 = @echo "  VALAC " $^;

-include $(top_srcdir)/git.mk
