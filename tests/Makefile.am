# NOTE: the data and lib dirs are first because they provide dependencies for
# the others
SUBDIRS = \
	data \
	lib \
	dummy \
	key-file \
	tools \
	$(NULL)

if ENABLE_BLUEZ
if HAVE_BLUEZ_TESTS
SUBDIRS += bluez
endif
endif

if ENABLE_TELEPATHY
SUBDIRS += folks telepathy
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
	dummy \
	eds \
	key-file \
	bluez \
	telepathy \
	libsocialweb \
	tracker \
	$(NULL)

EXTRA_DIST = \
	test.mk \
	$(NULL)

-include $(top_srcdir)/git.mk
