SUBDIRS = \
	telepathy \
	key-file \
	$(NULL)

if ENABLE_TRACKER
SUBDIRS += tracker
endif

DIST_SUBDIRS = \
	telepathy \
	key-file \
	$(NULL)

if ENABLE_TRACKER
DIST_SUBDIRS += tracker
endif

-include $(top_srcdir)/git.mk
