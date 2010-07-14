SUBDIRS = \
	folks \
	backends \
	$(NULL)

if ENABLE_DOCS
SUBDIRS += docs
endif

ACLOCAL_AMFLAGS = -I m4

DISTCHECK_CONFIGURE_FLAGS =		\
	--enable-gtk-doc		\
	--disable-schemas-install

folksdocdir = ${prefix}/doc/folks
folksdoc_DATA = \
	ChangeLog \
	README \
	COPYING \
	AUTHORS \
	INSTALL \
	NEWS\
	$(NULL)

EXTRA_DIST = \
	$(folksdoc_DATA) \
	autogen.sh \
	$(NULL)

DISTCLEANFILES = \
	ChangeLog \
	$(NULL)

distclean-local:
	if test "x$(srdcir)" = "x."; then :; else \
		rm -f ChangeLog; \
	fi

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

