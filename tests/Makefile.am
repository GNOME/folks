SUBDIRS = \
    lib \
    $(NULL)

if HAVE_TP_GLIB_FOR_TESTS
SUBDIRS += telepathy
endif

TESTS_ENVIRONMENT = \
    abs_top_builddir=@abs_top_builddir@ \
    abs_top_srcdir=@abs_top_srcdir@ \
    G_SLICE=debug-blocks \
    G_DEBUG=fatal_warnings,fatal_criticals \
    PYTHONPATH=@abs_top_srcdir@/tools

-include $(top_srcdir)/git.mk
