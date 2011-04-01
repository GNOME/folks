EXTRA_DIST = \
	backend-store-all.ini \
	gconf.path \
	gconf.path.in \
	$(NULL)

clean-gconf:
	rm -rf gconf.d gconf.path

clean-local: clean-gconf

check: clean-gconf

GITIGNOREFILES = \
	gconf.d \
	gconf.path \
	$(NULL)

.PHONY: clean-gconf clean-local

-include $(top_srcdir)/git.mk
