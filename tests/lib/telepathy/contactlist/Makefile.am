# Taken from telepathy-glib. The only change is to remove the option to install # the data files.
#
# PLEASE DO NOT MODIFY THIS CONNECTION MANAGER. Either subclass it,
# copy-and-modify (moving it to a better namespace), or make changes in the
# copy in telepathy-glib first.

VAPIGENFLAGS += \
	--vapidir=. \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--pkg gmodule-2.0 \
	--pkg dbus-glib-1 \
	--pkg telepathy-glib \
	$(NULL)

noinst_LTLIBRARIES = libtp-test-contactlist.la

libtp_test_contactlist_la_SOURCES = \
        _gen/param-spec-struct.h \
        account.c \
        account.h \
        account-manager.c \
        account-manager.h \
        backend.c \
        backend.h \
        conn.c \
        conn.h \
        contact-list.c \
        contact-list.h \
        contact-list-manager.c \
        contact-list-manager.h \
	$(NULL)

libtp_test_contactlist_la_CFLAGS = \
	$(ERROR_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	$(DBUS_GLIB_CFLAGS) \
	$(NULL)
libtp_test_contactlist_la_LIBADD = \
	$(TP_GLIB_LIBS) \
	$(DBUS_GLIB_LIBS) \
	$(NULL)

_gen/tp_test_contact_list.manager _gen/param-spec-struct.h: \
			manager-file.py $(top_srcdir)/tests/tools/manager-file.py
		$(AM_V_at)$(mkdir_p) _gen
		$(AM_V_GEN)$(PYTHON) $(top_srcdir)/tests/tools/manager-file.py \
			$(srcdir)/manager-file.py _gen

DISTCHECK_CONFIGURE_FLAGS = --enable-introspection

-include $(INTROSPECTION_MAKEFILE)
INTROSPECTION_GIRS =
INTROSPECTION_SCANNER_ARGS = --add-include-path=$(srcdir)
INTROSPECTION_COMPILER_ARGS = --includedir=$(srcdir)

tp-test-contactlist.gir: libtp-test-contactlist.la
tp_test_contactlist_gir_INCLUDES = GObject-2.0 TelepathyGLib-0.12
tp_test_contactlist_gir_CFLAGS = $(TP_GLIB_CFLAGS)
tp_test_contactlist_gir_LIBS = libtp-test-contactlist.la
tp_test_contactlist_gir_FILES = $(libtp_test_contactlist_la_SOURCES)
tp_test_contactlist_gir_NAMESPACE = TpTest
INTROSPECTION_GIRS += tp-test-contactlist.gir

tp-test-contactlist.vapi: tp-test-contactlist.gir
	$(AM_V_GEN)$(VAPIGEN) $(VAPIGENFLAGS) --library tp-test-contactlist \
		tp-test-contactlist.gir

BUILT_SOURCES = \
	tp-test-contactlist.gir \
	tp-test-contactlist.vapi \
	$(NULL)

CLEANFILES = \
	_gen/param-spec-struct.h \
	_gen/tp_test_contact_list.manager \
	$(gir_DATA) \
	$(typelib_DATA) \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(BUILT_SOURCES) \
	tp-test-contactlist.gir \
	tp-test-contactlist.vapi \
	$(NULL)

EXTRA_DIST = \
	$(MAINTAINERCLEANFILES) \
	manager-file.py \
	session.conf \
	tp-test-contactlist.h \
	$(NULL)

clean-local:
	rm -rf _gen

-include $(top_srcdir)/git.mk
