SUBDIRS = lib

AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/telepathy/lib \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DG_LOG_DOMAIN=\"TelepathyBackend\" \
	$(NULL)

VALAFLAGS += \
	--vapidir=. \
	--vapidir=$(top_builddir)/backends/telepathy/lib \
	--vapidir=$(top_srcdir)/folks

backenddir = $(BACKEND_DIR)/telepathy
backend_LTLIBRARIES = libfolks-backend-telepathy.la

##################################################################
# Backend
##################################################################

folks_backend_telepathy_valasources = \
	tp-backend.vala \
	tp-backend-factory.vala \
	$(NULL)

folks_backend_telepathy_deps = \
	folks \
	folks-telepathy \
	gee-1.0 \
	gio-2.0 \
	gobject-2.0 \
	telepathy-glib \
	$(NULL)

libfolks_backend_telepathy_la_SOURCES = \
	$(folks_backend_telepathy_valasources:.vala=.c)

libfolks_backend_telepathy_la_CPPFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(DBUS_GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	$(AM_CPPFLAGS) \
	$(NULL)

libfolks_backend_telepathy_la_LIBADD = \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(DBUS_GLIB_LIBS) \
	$(GEE_LIBS) \
	$(TP_GLIB_LIBS) \
	lib/libfolks-telepathy.la \
	$(NULL)

libfolks_backend_telepathy_la_LDFLAGS = -shared -fPIC -module -avoid-version

folks-backend-telepathy.h $(libfolks_backend_telepathy_la_SOURCES): \
	folks-backend-telepathy.vala.stamp

folks-backend-telepathy.vapi folks-backend-telepathy.vala.stamp: $(folks_backend_telepathy_valasources)
	$(VALA_V)$(VALAC) $(VALACFLAGS) $(VALAFLAGS) \
		-H folks-backend-telepathy.h -C \
		--library folks-backend-telepathy \
		$(addprefix --pkg ,$(folks_backend_telepathy_deps)) \
		$(addprefix $(srcdir)/,$(folks_backend_telepathy_valasources))
	touch $@

##################################################################
# General
##################################################################

EXTRA_DIST = \
	$(folks_backend_telepathy_valasources) \
	folks-backend-telepathy.vala.stamp \
	folks-backend-telepathy.vapi \
	$(NULL)

CLEANFILES = \
	folks-backend-telepathy.h \
	folks-backend-telepathy.vala.stamp \
	folks-backend-telepathy.vapi \
	$(libfolks_backend_telepathy_la_SOURCES) \
	$(NULL)

MAINTAINERCLEANFILES = $(libfolks_backend_telepathy_la_SOURCES)

# set up the verbosity rules to avoid some build noise
# XXX: once automake >= 1.11 is common, remove these, push valasources files
# into SOURCES and add AM_PROG_VALAC to configure.ac
VALA_V = $(VALA_V_$(V))
VALA_V_ = $(VALA_V_$(AM_DEFAULT_VERBOSITY))
VALA_V_0 = @echo "  VALAC " $^;

-include $(top_srcdir)/git.mk
