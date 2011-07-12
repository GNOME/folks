SUBDIRS = \
	telepathy \
	key-file \
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
	telepathy \
	key-file \
	tracker \
	libsocialweb \
	eds \
	$(NULL)

-include $(top_srcdir)/git.mk
