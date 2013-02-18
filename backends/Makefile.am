SUBDIRS = \
	key-file \
	$(NULL)

if ENABLE_TELEPATHY
SUBDIRS += telepathy
endif

if ENABLE_LIBSOCIALWEB
SUBDIRS += libsocialweb
endif

if ENABLE_TRACKER
SUBDIRS += tracker
endif

if ENABLE_EDS
SUBDIRS += eds
endif

if ENABLE_OFONO
SUBDIRS += ofono
endif

DIST_SUBDIRS = \
	eds \
	key-file \
	libsocialweb \
	ofono \
	telepathy \
	tracker \
	$(NULL)

-include $(top_srcdir)/git.mk
