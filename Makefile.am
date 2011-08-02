ACLOCAL_AMFLAGS = -I m4

SUBDIRS = \
	folks \
	backends \
	tests \
	tools \
	po \
	$(NULL)

if HAVE_VALADOC
SUBDIRS += docs
endif

DISTCHECK_CONFIGURE_FLAGS = \
	--enable-docs \
	--disable-vala \
	$(NULL)

EXTRA_DIST = \
	autogen.sh \
	$(NULL)

MAINTAINERCLEANFILES = \
	ABOUT-NLS \
	$(srcdir)/INSTALL \
	$(srcdir)/aclocal.m4 \
	$(srcdir)/compile \
	$(srcdir)/config.guess \
	$(srcdir)/config.h.in \
	$(srcdir)/config.rpath \
	$(srcdir)/config.sub \
	$(srcdir)/depcomp \
	$(srcdir)/install-sh \
	$(srcdir)/ltmain.sh \
	$(srcdir)/missing \
	$(srcdir)/mkinstalldirs \
	$(srcdir)/ChangeLog \
	`find "$(srcdir)" -type f -name Makefile.in -print` \
	`find "m4" -type f -name "*.m4" ! -name "as-compiler-flag.m4" ! -name "introspection.m4" ! -name "vala.m4" -print` \
	po/Makevars.template \
	po/Rules-quot \
	po/boldquot.sed \
	po/en@boldquot.header \
	po/en@quot.header \
	po/insert-header.sin \
	po/missing \
	po/quot.sed \
	po/remove-potcdate.sin \
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

-include $(top_srcdir)/git.mk
