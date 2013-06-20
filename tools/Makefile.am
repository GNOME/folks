# Inspector
DIST_SUBDIRS = inspect

if ENABLE_INSPECT_TOOL
SUBDIRS = inspect
endif

# Importer
if ENABLE_IMPORT_TOOL
bin_PROGRAMS = folks-import
endif

AM_VALAFLAGS += \
	--vapidir=$(top_builddir)/folks \
	--pkg=gee-0.8 \
	--pkg=libxml-2.0 \
	--pkg=folks \
	--pkg=build-conf \
	$(NULL)

folks_import_SOURCES = \
	import.vala \
	import-pidgin.vala \
	$(NULL)
folks_import_CPPFLAGS = \
	$(AM_CPPFLAGS) \
	-include $(CONFIG_HEADER) \
	-DLOCALE_DIR=\"$(localedir)\" \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	$(NULL)
folks_import_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(LIBXML_CFLAGS) \
	$(NULL)
folks_import_LDADD = \
	$(AM_LDADD) \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(LIBXML_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(NULL)

-include $(top_srcdir)/git.mk
