# Taken from telepathy-glib. The only change is to remove the option to install # the data files.
#
# PLEASE DO NOT MODIFY THIS CONNECTION MANAGER. Either subclass it,
# copy-and-modify (moving it to a better namespace), or make changes in the
# copy in telepathy-glib first.

VAPIGENFLAGS += \
	--vapidir=. \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg gmodule-2.0 \
	--pkg dbus-glib-1 \
	--pkg telepathy-glib \
	$(NULL)

noinst_LTLIBRARIES = libtp-test-contactlist.la

nodist_libtp_test_contactlist_la_SOURCES = \
        _gen/param-spec-struct.h \
	$(NULL)

libtp_test_contactlist_la_SOURCES = \
        backend.c \
        backend.h \
        contact-list-manager.c \
        contact-list-manager.h \
        contacts-conn.c \
        contacts-conn.h \
        debug.h \
        room-list-chan.c \
        room-list-chan.h \
        simple-account.c \
        simple-account.h \
        simple-account-manager.c \
        simple-account-manager.h \
        simple-conn.c \
        simple-conn.h \
        textchan-null.c \
        textchan-null.h \
        util.c \
        util.h \
	$(NULL)

libtp_test_contactlist_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(C_ERROR_CFLAGS) \
	$(TP_GLIB_CFLAGS) \
	$(DBUS_GLIB_CFLAGS) \
	$(NULL)
libtp_test_contactlist_la_LIBADD = \
	$(TP_GLIB_LIBS) \
	$(DBUS_GLIB_LIBS) \
	$(NULL)

_gen/tp_test_contact_list.manager _gen/param-spec-struct.h: \
			manager-file.py $(top_srcdir)/tests/tools/manager-file.py
		$(AM_V_at)$(MKDIR_P) _gen
		$(AM_V_GEN)$(PYTHON) $(top_srcdir)/tests/tools/manager-file.py \
			$(srcdir)/manager-file.py _gen

DISTCHECK_CONFIGURE_FLAGS = --enable-introspection

-include $(INTROSPECTION_MAKEFILE)
INTROSPECTION_GIRS =
INTROSPECTION_SCANNER_ARGS = --add-include-path=$(srcdir)
INTROSPECTION_COMPILER_ARGS = --includedir=$(srcdir)

tp-test-contactlist.gir: $(libtp_test_contactlist_la_SOURCES) \
	libtp-test-contactlist.la
tp_test_contactlist_gir_INCLUDES = GObject-2.0 TelepathyGLib-0.12
tp_test_contactlist_gir_CFLAGS = $(TP_GLIB_CFLAGS)
tp_test_contactlist_gir_LIBS = libtp-test-contactlist.la
tp_test_contactlist_gir_FILES = $(libtp_test_contactlist_la_SOURCES)
tp_test_contactlist_gir_NAMESPACE = TpTests
INTROSPECTION_GIRS += tp-test-contactlist.gir

if HAVE_VALA
# The .vapi is output in the $(builddir), and valac looks for .deps
# in the same directory as the .vapi rather than going through the search
# path again, so we need to copy the .deps to the $(builddir) too.
tp-test-contactlist.vapi: tp-test-contactlist.gir tp-test-contactlist.deps
	@test x$(srcdir) = x. || cp $(srcdir)/tp-test-contactlist.deps .
	$(MAKE) $(AM_MAKEFLAGS) tp-test-contactlist.gir
	$(AM_V_GEN)$(VAPIGEN) $(VAPIGENFLAGS) --library tp-test-contactlist \
		tp-test-contactlist.gir
	touch $@
endif

introspection_files = \
	$(INTROSPECTION_GIRS) \
	tp-test-contactlist.vapi \
	$(NULL)

dist_noinst_DATA = \
	$(introspection_files) \
	tp-test-contactlist.deps \
	$(NULL)

CLEANFILES = \
	_gen/param-spec-struct.h \
	_gen/tp_test_contact_list.manager \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(introspection_files) \
	$(NULL)

DISTCLEANFILES =

if NOT_RELEASE
DISTCLEANFILES += $(dist_noinst_DATA)
endif

EXTRA_DIST = \
	manager-file.py \
	tp-test-contactlist.h \
	$(NULL)

clean-local:
	rm -rf _gen
	test x$(srcdir) = x. || rm -f tp-test-contactlist.deps

-include $(top_srcdir)/git.mk
