# NOTE: the data and lib dirs are first because they provide dependencies for
# the others
SUBDIRS = \
	data \
	lib \
	key-file \
	tools \
	$(NULL)

if ENABLE_TELEPATHY
SUBDIRS += folks telepathy
endif

if ENABLE_LIBSOCIALWEB
SUBDIRS += libsocialweb
endif

if ENABLE_EDS
SUBDIRS += eds
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
