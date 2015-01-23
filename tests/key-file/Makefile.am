include $(top_srcdir)/tests/test.mk

AM_VALAFLAGS = \
	$(test_valaflags) \
	--vapidir=$(top_srcdir)/tests/lib/key-file \
	--pkg kf-test \
	$(NULL)

AM_CPPFLAGS = \
	$(test_cppflags) \
	-I$(top_srcdir)/tests/lib/key-file \
	$(NULL)

AM_CFLAGS = \
	$(test_cflags) \
	$(NULL)

LDADD = \
	$(AM_LDADD) \
	$(test_ldadd) \
	$(top_builddir)/tests/lib/key-file/libkf-test.la \
	$(NULL)

# in order from least to most complex
all_test_programs = \
	individual-retrieval \
	$(NULL)
installed_tests_subdirectory = key-file

individual_retrieval_SOURCES = \
	individual-retrieval.vala \
	$(NULL)

-include $(top_srcdir)/git.mk
-include $(top_srcdir)/valgrind.mk
-include $(top_srcdir)/check.mk
