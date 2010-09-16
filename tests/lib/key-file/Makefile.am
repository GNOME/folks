VALAFLAGS += \
	--library=kf-test \
	--header=kf-test.h \
	--vapidir=. \
	$(NULL)

noinst_LTLIBRARIES = libkf-test.la

libkf_test_la_SOURCES = \
	backend.vala \
	$(NULL)

libkf_test_la_CFLAGS = \
	$(GLIB_CFLAGS) \
	$(NULL)

libkf_test_la_LIBADD = \
	$(GLIB_LIBS) \
	$(NULL)

MAINTAINERCLEANFILES = \
	kf-test.vapi \
	kf-test.h \
	$(NULL)

GITIGNOREFILES = \
	$(libkf_test_la_SOURCES:.vala=.c) \
	libkf_test_la_vala.stamp \
	$(NULL)

-include $(top_srcdir)/git.mk
