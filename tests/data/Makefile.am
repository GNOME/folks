EXTRA_DIST = \
	backend-store-all.ini \
	$(NULL)

clean-gconf:
	rm -rf gconf.d

clean-local: clean-gconf

check: clean-gconf

GITIGNOREFILES = \
	gconf.d \
	gconf.path \
	$(NULL)

.PHONY: clean-gconf clean-local

-include $(top_srcdir)/git.mk
