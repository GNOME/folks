# Pass FOLKS_TEST_VALGRIND=1 to make to enable Valgrind on the tests
# This file must be included _after_ TESTS_ENVIRONMENT has been set by the Makefile.am.

ifeq ($(FOLKS_TEST_CALLGRIND),1)
TESTS_ENVIRONMENT := \
	$(TESTS_ENVIRONMENT) \
	$(LIBTOOL) --mode=execute valgrind --tool=callgrind
endif

ifeq ($(FOLKS_TEST_VALGRIND),1)
TESTS_ENVIRONMENT := \
	G_DEBUG=$(G_DEBUG),gc-friendly \
	G_SLICE=$(G_SLICE),always-malloc \
	$(TESTS_ENVIRONMENT) \
	$(LIBTOOL) --mode=execute valgrind \
		--leak-check=full \
		--show-reachable=no \
		--gen-suppressions=all \
		--num-callers=20 \
		--error-exitcode=0 \
		--log-file=valgrind.log.%p
endif
