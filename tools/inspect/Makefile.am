AM_VALAFLAGS += \
	--vapidir=$(top_srcdir)/folks \
	--pkg=posix \
	--pkg=readline \
	--pkg=gobject-2.0 \
	--pkg=gio-2.0 \
	--pkg=gee-0.8 \
	--pkg=posix \
	--pkg=folks \
	--pkg=build-conf \
	$(NULL)

bin_PROGRAMS = folks-inspect

folks_inspect_SOURCES = \
	command-backends.vala \
	command-debug.vala \
	command-help.vala \
	command-individuals.vala \
	command-linking.vala \
	command-persona-stores.vala \
	command-personas.vala \
	command-quit.vala \
	command-set.vala \
	command-signals.vala \
	signal-manager.vala \
	utils.vala \
	inspect.vala \
	$(NULL)
folks_inspect_LDADD = \
	$(AM_LDADD) \
	$(LIBREADLINE) \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/folks/libfolks.la \
	$(NULL)
folks_inspect_CPPFLAGS = \
	$(AM_CPPFLAGS) \
	-include $(CONFIG_HEADER) \
	-DLOCALE_DIR=\"$(localedir)\" \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	$(NULL)
folks_inspect_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

-include $(top_srcdir)/git.mk
