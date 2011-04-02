EXTRA_DIST = \
	backend-store-all.ini \
	gconf.path \
	gconf.path.in \
	$(NULL)

clean-gconf:
	rm -rf gconf.d

clean-local: clean-gconf

check: clean-gconf

CLEANFILES = \
	gconf.path \
	$(NULL)

GITIGNOREFILES = \
	gconf.d \
	$(NULL)

.PHONY: clean-gconf clean-local

-include $(top_srcdir)/git.mk
