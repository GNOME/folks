SUBDIRS = \
    data \
    lib \
    tools \
    folks \
    key-file \
    telepathy \
    $(NULL)

if ENABLE_TRACKER
SUBDIRS += tracker
endif

DIST_SUBDIRS = \
    data \
    lib \
    tools \
    folks \
    key-file \
    telepathy \
    $(NULL)

if ENABLE_TRACKER
DIST_SUBDIRS += tracker
endif

TESTS_ENVIRONMENT = \
    abs_top_builddir=@abs_top_builddir@ \
    abs_top_srcdir=@abs_top_srcdir@ \
    G_SLICE=debug-blocks \
    G_DEBUG=fatal_warnings,fatal_criticals \
    PYTHONPATH=@abs_top_srcdir@/tools

-include $(top_srcdir)/git.mk
