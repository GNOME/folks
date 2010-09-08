if HAVE_LIBXML
bin_PROGRAMS = folks-import
endif

VALAFLAGS = \
	--vapidir=$(top_builddir)/folks \
	--pkg=gee-1.0 \
	--pkg=libxml-2.0 \
	--pkg=folks \
	$(NULL)

folks_import_SOURCES = \
	import.vala \
	import-pidgin.vala \
	$(NULL)
folks_import_CFLAGS = \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(LIBXML_CFLAGS) \
	-I$(top_srcdir)/folks \
	$(NULL)
folks_import_LDADD = \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(LIBXML_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(NULL)

GITIGNOREFILES = \
	folks_import_vala.stamp \
	$(folks_import_SOURCES:.vala=.c) \
	$(NULL)

-include $(top_srcdir)/git.mk
