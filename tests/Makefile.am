SUBDIRS = \
    data \
    lib \
    tools \
    folks \
    key-file \
    telepathy \
    $(NULL)

if ENABLE_LIBSOCIALWEB
SUBDIRS += libsocialweb
endif

if ENABLE_TRACKER
SUBDIRS += tracker
endif

if ENABLE_EDS
SUBDIRS += eds
endif

DIST_SUBDIRS = \
    data \
    lib \
    tools \
    folks \
    key-file \
    telepathy \
    libsocialweb \
    tracker \
    eds \
    $(NULL)

TESTS_ENVIRONMENT = \
    abs_top_builddir=@abs_top_builddir@ \
    abs_top_srcdir=@abs_top_srcdir@ \
    G_SLICE=debug-blocks \
    G_DEBUG=fatal_warnings,fatal_criticals \
    PYTHONPATH=@abs_top_srcdir@/tools

EXTRA_DIST = \
	$(srcdir)/data/avatar-01.jpg \
	$(NULL)

-include $(top_srcdir)/git.mk
