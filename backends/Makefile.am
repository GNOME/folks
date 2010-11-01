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

DIST_SUBDIRS = \
	telepathy \
	key-file \
	tracker \
	libsocialweb \
	$(NULL)

-include $(top_srcdir)/git.mk
