AM_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/telepathy \
	-I$(top_srcdir)/backends/telepathy/lib \
	-I$(top_srcdir)/tests/lib \
	-I$(top_srcdir)/tests/lib/telepathy/contactlist \
	-include $(CONFIG_HEADER) \
	$(NULL)

LDADD = \
	$(top_builddir)/tests/lib/libfolks-test.la \
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
	--vapidir=$(top_builddir)/tests/lib/ \
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
	--pkg folks-test \
	--pkg tp-test-contactlist \
	$(NULL)

# in order from least to most complex
noinst_PROGRAMS = \
	persona-store-capabilities \
	individual-retrieval \
	individual-properties \
	$(NULL)

TESTS = $(addprefix test-,$(noinst_PROGRAMS))

persona_store_capabilities_SOURCES = \
	persona-store-capabilities.vala \
	$(NULL)

individual_retrieval_SOURCES = \
	individual-retrieval.vala \
	$(NULL)

individual_properties_SOURCES = \
	individual-properties.vala \
	$(NULL)

CLEANFILES = \
	$(addsuffix .c,$(noinst_PROGRAMS)) \
	*.stamp \
	*.pid \
	*.address \
	$(TESTS) \
	$(NULL)

test-%: %
	{ echo "#!/bin/sh" && \
	echo -n "$(RUN_WITH_PRIVATE_BUS) " && \
	echo "--config-file=$(top_builddir)/tests/lib/telepathy/contactlist/session.conf -- ./$<"; } \
	> $@
	chmod +x $@

-include $(top_srcdir)/git.mk
