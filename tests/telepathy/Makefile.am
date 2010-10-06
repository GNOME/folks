AM_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/telepathy \
	-I$(top_srcdir)/backends/telepathy/lib \
	-I$(top_srcdir)/tests/lib/telepathy/contactlist \
	-include $(CONFIG_HEADER) \
	$(NULL)

LDADD = \
	$(top_builddir)/tests/lib/telepathy/contactlist/libtp-test-contactlist.la \
	$(top_builddir)/backends/telepathy/lib/libfolks-telepathy.la \
	$(top_builddir)/folks/libfolks.la
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(TP_GLIB_LIBS) \
	-L$(top_srcdir)/backends/telepathy/lib \
	$(NULL)

RUN_WITH_PRIVATE_BUS = $(top_srcdir)/tests/tools/with-session-bus.sh

VALAFLAGS += \
	--vapidir=$(top_builddir)/tests/lib/telepathy/contactlist/ \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/telepathy/lib \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--pkg gmodule-2.0 \
	--pkg dbus-glib-1 \
	--pkg telepathy-glib \
	--pkg folks \
	--pkg folks-telepathy \
	--pkg tp-test-contactlist \
	$(NULL)

# in order from least to most complex
TESTS = \
	test-contact-retrieval \
	test-contact-properties \
	$(NULL)

noinst_PROGRAMS = \
	contact-retrieval \
	contact-properties \
	$(NULL)

# FIXME: turn test-case into a library that the tests use or push it into the
# existing library
contact_retrieval_SOURCES = \
	test-case.vala \
	contact-retrieval.vala \
	$(NULL)

contact_properties_SOURCES = \
	test-case.vala \
	contact-properties.vala \
	$(NULL)

CLEANFILES = \
	$(TESTS) \
	$(NULL)

test-%: %
	{ echo "#!/bin/sh" && \
	echo -n "$(RUN_WITH_PRIVATE_BUS) " && \
	echo "--config-file=$(top_builddir)/tests/lib/telepathy/contactlist/session.conf -- ./$<"; } \
	> $@
	chmod +x $@

#FIXME: simplify if possible
GITIGNOREFILES = \
	$(contact_retrieval_SOURCES:.vala=.c) \
	contact_retrieval_vala.stamp \
	$(contact_properties_SOURCES:.vala=.c) \
	contact_properties_vala.stamp \
	$(NULL)

-include $(top_srcdir)/git.mk
