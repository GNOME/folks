AM_CPPFLAGS = \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/telepathy \
	-I$(top_srcdir)/tests/lib/telepathy/contactlist \
	-include $(CONFIG_HEADER) \
	$(NULL)

LDADD = \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(TP_GLIB_LIBS) \
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

noinst_PROGRAMS = \
	contact-retrieval \
	$(NULL)

TESTS_ENVIRONMENT = \
	FOLKS_BACKEND_KEY_FILE_PATH=$(srcdir)/data/relationships-empty.ini
TESTS = $(addprefix test-,$(noinst_PROGRAMS))

contact_retrieval_SOURCES = \
	test-case.vala \
	contact-retrieval.vala \
	$(NULL)

contact_retrieval_LDADD = \
	$(top_builddir)/tests/lib/telepathy/contactlist/libtp-test-contactlist.la \
	$(top_builddir)/folks/libfolks.la

CLEANFILES = \
	$(TESTS) \
	$(NULL)

test-contact-retrieval: contact-retrieval
	{ echo "#!/bin/sh" && \
	echo -n "$(RUN_WITH_PRIVATE_BUS) " && \
	echo "--config-file=$(top_builddir)/tests/lib/telepathy/contactlist/session.conf -- ./$<"; } \
	> $@
	chmod +x $@

GITIGNOREFILES = \
	$(contact_retrieval_SOURCES:.vala=.c) \
	contact_retrieval_vala.stamp \
	$(NULL)

-include $(top_srcdir)/git.mk
