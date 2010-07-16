AM_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DG_LOG_DOMAIN=\"KeyFileBackend\" \
	$(NULL)

VALAFLAGS += --vapidir=. --vapidir=$(top_srcdir)/folks

backenddir = $(BACKEND_DIR)/key-file
backend_LTLIBRARIES = libfolks-backend-key-file.la

folks_backend_key_file_valasources = \
	kf-backend.vala \
	kf-backend-factory.vala \
	kf-persona.vala \
	kf-persona-store.vala \
	$(NULL)

folks_backend_key_file_deps = \
	folks \
	gee-1.0 \
	gio-2.0 \
	gobject-2.0 \
	$(NULL)

libfolks_backend_key_file_la_SOURCES = \
	$(folks_backend_key_file_valasources:.vala=.c)

libfolks_backend_key_file_la_CPPFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(AM_CPPFLAGS) \
	$(NULL)

libfolks_backend_key_file_la_LIBADD = \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

libfolks_backend_key_file_la_LDFLAGS = -shared -fPIC -module -avoid-version

folks-backend-key-file.h $(libfolks_backend_key_file_la_SOURCES): \
		folks-backend-key-file.vala.stamp

folks-backend-key-file.vapi folks-backend-key-file.vala.stamp: $(folks_backend_key_file_valasources)
	$(VALA_V)$(VALAC) $(VALACFLAGS) $(VALAFLAGS) \
		-H folks-backend-key-file.h -C \
		--library folks-backend-key-file \
		$(addprefix --pkg ,$(folks_backend_key_file_deps)) \
		$(addprefix $(srcdir)/,$(folks_backend_key_file_valasources))
	touch $@

BUILT_SOURCES = \
	folks-backend-key-file.h \
	folks-backend-key-file.vala.stamp \
	folks-backend-key-file.vapi \
	$(libfolks_backend_key_file_la_SOURCES) \
	$(NULL)

EXTRA_DIST = \
	$(folks_backend_key_file_valasources) \
	folks-backend-key-file.vala.stamp \
	folks-backend-key-file.vapi \
	$(NULL)

CLEANFILES = \
	$(BUILT_SOURCES) \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(libfolks_backend_key_file_la_SOURCES) \
	$(NULL)

# set up the verbosity rules to avoid some build noise
# XXX: once automake >= 1.11 is common, remove these, push valasources files
# into SOURCES and add AM_PROG_VALAC to configure.ac
VALA_V = $(VALA_V_$(V))
VALA_V_ = $(VALA_V_$(AM_DEFAULT_VERBOSITY))
VALA_V_0 = @echo "  VALAC " $^;

-include $(top_srcdir)/git.mk
