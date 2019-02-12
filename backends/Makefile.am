SUBDIRS = \
	dummy \
	key-file \
	$(NULL)

if ENABLE_TELEPATHY
SUBDIRS += telepathy
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

if ENABLE_BLUEZ
SUBDIRS += bluez
endif

DIST_SUBDIRS = \
	bluez \
	eds \
	key-file \
	ofono \
	telepathy \
	tracker \
	dummy \
	$(NULL)

EXTRA_DIST = \
	backend.mk \
	backend-library.mk \
	$(NULL)

-include $(top_srcdir)/git.mk
