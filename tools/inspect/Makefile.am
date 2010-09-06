VALAFLAGS = \
	--vapidir=$(top_srcdir)/folks \
	--pkg=readline \
	--pkg=gobject-2.0 \
	--pkg=gee-1.0 \
	--pkg=folks \
	$(NULL)

bin_PROGRAMS = folks-inspect

folks_inspect_SOURCES = \
	command-backends.vala \
	command-help.vala \
	command-individuals.vala \
	command-persona-stores.vala \
	command-personas.vala \
	command-quit.vala \
	command-signals.vala \
	signal-manager.vala \
	utils.vala \
	inspect.vala \
	$(NULL)
folks_inspect_LDADD = \
	$(LIBREADLINE) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(NULL)
folks_inspect_CFLAGS = \
	-I$(top_srcdir)/folks \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

GITIGNOREFILES = \
	folks_inspect_vala.stamp \
	$(folks_inspect_SOURCES:.vala=.c) \
	$(NULL)

-include $(top_srcdir)/git.mk
