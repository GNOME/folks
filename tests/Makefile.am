SUBDIRS = \
    data \
    lib \
    tools \
    folks \
    $(NULL)

if ENABLE_TELEPATHY
SUBDIRS += telepathy
endif

if ENABLE_LIBSOCIALWEB
SUBDIRS += libsocialweb
endif

if ENABLE_EDS
SUBDIRS += eds
endif

SUBDIRS += key-file

# XXX: keep Tracker at the end, since it's the most likely to fail (in ways we
# can't easily control)
if ENABLE_TRACKER
SUBDIRS += tracker
endif

DIST_SUBDIRS = \
    data \
    lib \
    tools \
    folks \
    eds \
    key-file \
    telepathy \
    libsocialweb \
    tracker \
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
