SUBDIRS = \
	data \
	key-file \
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

-include $(top_srcdir)/git.mk
