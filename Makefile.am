ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}

SUBDIRS = \
	folks \
	backends \
	tools \
	po \
	$(NULL)

if ENABLE_BUILD_TESTS
SUBDIRS += tests
endif

if HAVE_VALADOC
SUBDIRS += docs
endif

DIST_SUBDIRS = \
	folks \
	backends \
	tools \
	tests \
	docs \
	po \
	$(NULL)

DISTCHECK_CONFIGURE_FLAGS = \
	--enable-docs \
	--enable-tests \
	--enable-eds-backend \
	--enable-telepathy-backend \
	--enable-libsocialweb-backend \
	--enable-tracker-backend \
	--enable-zeitgeist \
	--disable-vala \
	--disable-fatal-warnings \
	$(NULL)

EXTRA_DIST = \
	autogen.sh \
	check.mk \
	lcov.mk \
	valgrind.mk \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(GITIGNORE_MAINTAINERCLEANFILES_M4_LIBTOOL) \
	$(GITIGNORE_MAINTAINERCLEANFILES_MAKEFILE_IN) \
	$(GITIGNORE_MAINTAINERCLEANFILES_TOPLEVEL) \
	ABOUT-NLS \
	$(top_builddir)/lcov.info \
	$(srcdir)/INSTALL \
	$(srcdir)/config.h.in \
	$(srcdir)/config.rpath \
	$(srcdir)/ChangeLog \
	$(NULL)

maintainer-clean-local: maintainer-clean-local-lcov
maintainer-clean-local-lcov:
	rm -rf $(top_builddir)/lcov.html

.PHONY: maintainer-clean-local-lcov

GITIGNOREFILES = \
	$(top_builddir)/lcov.html/* \
	$(NULL)

distclean-local:
	if test "x$(srcdir)" = "x."; then :; else \
		rm -f ChangeLog; \
	fi

distcleancheck_listfiles = \
	find . -type f -exec sh -c 'test -f $(srcdir)/$$1 || echo $$1' \
		sh '{}' ';'

maintainer-upload-release:
	$(MAKE) -C docs maintainer-upload-release

ChangeLog:
	@echo Creating $@
	@if test -d "$(srcdir)/.git"; then \
	  (GIT_DIR=$(top_srcdir)/.git ./missing --run git log --stat) | fmt --split-only > $@.tmp \
	  && mv -f $@.tmp $@ \
	  || ($(RM) $@.tmp; \
	      echo Failed to generate ChangeLog, your ChangeLog may be outdated >&2; \
	      (test -f $@ || echo git-log is required to generate this file >> $@)); \
	else \
	  test -f $@ || \
	  (echo A git checkout and git-log is required to generate ChangeLog >&2 && \
	  echo A git checkout and git-log is required to generate this file >> $@); \
	fi

.PHONY: ChangeLog

# Code coverage support
include lcov.mk

-include $(top_srcdir)/git.mk
