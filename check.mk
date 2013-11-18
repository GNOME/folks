# taken from gstreamer
# gdb any given test by running make test.gdb
%.gdb: %
	$(TESTS_ENVIRONMENT) \
	$(LIBTOOL) --mode=execute \
	gdb $*
