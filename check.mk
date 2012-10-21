# taken from gstreamer
# gdb any given test by running make test.gdb
%.gdb: %
	CHECK_VERBOSE=1 \
	$(TESTS_ENVIRONMENT) \
	$(LIBTOOL) --mode=execute \
	gdb $*
