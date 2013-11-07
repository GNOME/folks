distclean_dirs = \
	folks \
	gtk-doc \
	$(NULL)

docs = \
	folks-doc \
	folks-gtk-doc \
	$(NULL)

upload_docs = \
	upload-docs-c-folks \
	upload-docs-vala-folks \
	$(NULL)

folks_wiki_pages = \
	concepts \
	glossary \
	debugging \
	$(NULL)

EXTRA_DIST = $(folks_wiki_files)

folksdocdir=$(datadir)/devhelp/references/folks

folksgtkdocdir=$(datadir)/gtk-doc/html/folks

common_doc_files = \
	*.css \
	*.png \
	*.js \
	index.htm \
	*.html \
	$(NULL)

folksdoc_DATA = \
	folks/folks/folks.devhelp2 \
	$(addprefix folks/folks/,$(common_doc_files)) \
	$(NULL)

folksgtkdoc_DATA = gtk-doc/folks/html/*

$(folksdoc_DATA): folks-doc.stamp
$(folksgtkdoc_DATA): folks-gtk-doc.stamp

valadoc_flags = \
	--force \
	--package-version $(PACKAGE_VERSION) \
	--no-protected \
	--driver "$(shell valac --api-version)" \
	$(NULL)

# folks documentation
folks_doc_files_blacklist = \
	$(top_srcdir)/folks/internal.vala \
	$(NULL)
# this expands the list of files, so we can filter out elements
folks_doc_files_all = \
	$(wildcard $(top_srcdir)/folks/*.vala) \
	$(NULL)
folks_wiki_files = \
	$(addprefix wiki/,$(addsuffix .valadoc,$(folks_wiki_pages))) \
	$(NULL)
# FIXME: sort the files manually to work around the native doclet portion of
# bgo#662784
folks_doc_files = \
	$(sort \
	$(filter-out $(folks_doc_files_blacklist),$(folks_doc_files_all)))
folks_doc_deps = \
	gmodule-2.0 \
	gio-2.0 \
	gee-0.8 \
	folks-internal \
	folks-generics \
	build-conf \
	$(NULL)
valadoc_flags_folks = \
	$(valadoc_flags) \
	-X $(top_srcdir)/folks/folks.h \
	$(addprefix --pkg=,$(folks_doc_deps)) \
	--vapidir=$(top_srcdir)/folks \
	--wiki=$(top_srcdir)/docs/wiki \
	$(folks_doc_files) \
	$(NULL)

folks-doc.stamp: $(folks_doc_files) $(folks_wiki_files)
	$(AM_V_GEN)$(VALADOC) \
		-o folks/ \
		--doclet=devhelp \
		$(valadoc_flags_folks) \
		$(NULL)
	@touch $@

folks-gtk-doc.stamp: $(folks_doc_files) $(folks_wiki_files)
	$(AM_V_GEN)$(VALADOC) \
		-X -l -X $(top_builddir)/folks/.libs/libfolks.so \
		-o gtk-doc/folks \
		--doclet=gtkdoc \
		$(valadoc_flags_folks) \
		$(NULL)
	@touch $@

#####################
# Dummy docs #
#####################

folksdummydocdir=$(datadir)/devhelp/references/folks-dummy
folksdummygtkdocdir=$(datadir)/gtk-doc/html/folks-dummy

folksdummydoc_DATA = \
	folks-dummy/folks-dummy/folks-dummy.devhelp2 \
	$(addprefix folks-dummy/folks-dummy/,$(common_doc_files))\
	$(NULL)

folksdummygtkdoc_DATA = gtk-doc/folks-dummy/html/*

$(folksdummydoc_DATA): \
	folks-dummy-doc.stamp \
	$(NULL)
$(folksdummygtkdoc_DATA): folks-dummy-gtk-doc.stamp

folks_dummy_doc_files = $(top_srcdir)/backends/dummy/lib/*.vala
folks_dummy_doc_deps = \
	gobject-2.0 \
	gio-2.0 \
	gee-0.8 \
	folks \
	folks-internal \
	$(NULL)
valadoc_flags_folks_dummy = \
	$(valadoc_flags) \
	-X $(top_srcdir)/backends/dummy/lib/folks/folks-dummy.h \
	$(addprefix --pkg=,$(folks_dummy_doc_deps)) \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/dummy/lib \
	$(folks_dummy_doc_files) \
	$(NULL)

folks-dummy-doc.stamp: $(folks_dummy_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-o folks-dummy/ \
		--doclet=devhelp \
		$(valadoc_flags_folks_dummy) \
		$(NULL)
	@touch $@

folks-dummy-gtk-doc.stamp: $(folks_dummy_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-X -l -X $(top_builddir)/folks/.libs/libfolks.so \
		-X -l -X $(top_builddir)/backends/dummy/lib/.libs/libfolks-dummy.so \
		-o gtk-doc/folks-dummy \
		--doclet=gtkdoc \
		$(valadoc_flags_folks_dummy) \
		$(NULL)
	@touch $@

distclean_dirs += folks-dummy
docs += \
	folks-dummy-doc \
	folks-dummy-gtk-doc \
	$(NULL)
upload_docs += upload-docs-c-folks-dummy upload-docs-vala-folks-dummy

#####################
# Telepathy docs #
#####################
folkstelepathydocdir=$(datadir)/devhelp/references/folks-telepathy
folkstelepathygtkdocdir=$(datadir)/gtk-doc/html/folks-telepathy

folkstelepathydoc_DATA = \
	folks-telepathy/folks-telepathy/folks-telepathy.devhelp2 \
	$(addprefix folks-telepathy/folks-telepathy/,$(common_doc_files))\
	$(NULL)

folkstelepathygtkdoc_DATA = gtk-doc/folks-telepathy/html/*

$(folkstelepathydoc_DATA): \
	folks-telepathy-doc.stamp \
	$(NULL)
$(folkstelepathygtkdoc_DATA): folks-telepathy-gtk-doc.stamp

# ensure we only have one set of tp-zeitgeist interfaces defined
folks_telepathy_doc_files_blacklist = \
	$(top_srcdir)/backends/telepathy/lib/tp-zeitgeist.vala \
	$(NULL)
# this expands the list of files, so we can filter out elements
folks_telepathy_doc_files_all = \
	$(wildcard $(top_srcdir)/backends/telepathy/lib/*.vala) \
	$(NULL)
# FIXME: sort the files manually to work around the native doclet portion of
# bgo#662784
folks_telepathy_doc_files = \
	$(sort \
	$(filter-out $(folks_telepathy_doc_files_blacklist),$(folks_telepathy_doc_files_all)))
folks_telepathy_doc_deps = \
	gmodule-2.0 \
	gio-2.0 \
	gee-0.8 \
	telepathy-glib \
	zeitgeist-2.0 \
	tp-lowlevel \
	build-conf \
	folks \
	folks-internal \
	folks-generics \
	$(NULL)
valadoc_flags_folks_telepathy = \
	$(valadoc_flags) \
	-X $(top_srcdir)/backends/telepathy/lib/folks/folks-telepathy.h \
	$(addprefix --pkg=,$(folks_telepathy_doc_deps)) \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/telepathy/lib \
	$(folks_telepathy_doc_files) \
	$(NULL)

folks-telepathy-doc.stamp: $(folks_telepathy_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-o folks-telepathy/ \
		--doclet=devhelp \
		$(valadoc_flags_folks_telepathy) \
		$(NULL)
	@touch $@

folks-telepathy-gtk-doc.stamp: $(folks_telepathy_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-X -l -X $(top_builddir)/folks/.libs/libfolks.so \
		-X -l -X $(top_builddir)/backends/telepathy/lib/.libs/libfolks-telepathy.so \
		-X --ignore-headers -X $(top_srcdir)/backends/telepathy/lib/tp-lowlevel.h \
		-o gtk-doc/folks-telepathy \
		--doclet=gtkdoc \
		$(valadoc_flags_folks_telepathy) \
		$(NULL)
	@touch $@

distclean_dirs += folks-telepathy
docs += \
	folks-telepathy-doc \
	folks-telepathy-gtk-doc \
	$(NULL)
upload_docs += upload-docs-c-folks-telepathy upload-docs-vala-folks-telepathy

#####################
# EDS docs #
#####################
if ENABLE_EDS
folksedsdocdir=$(datadir)/devhelp/references/folks-eds
folksedsgtkdocdir=$(datadir)/gtk-doc/html/folks-eds

folksedsdoc_DATA = \
	folks-eds/folks-eds/folks-eds.devhelp2 \
	$(addprefix folks-eds/folks-eds/,$(common_doc_files))\
	$(NULL)

folksedsgtkdoc_DATA = gtk-doc/folks-eds/html/*

$(folksedsdoc_DATA): \
	folks-eds-doc.stamp \
	$(NULL)
$(folksedsgtkdoc_DATA): folks-eds-gtk-doc.stamp

folks_eds_doc_files = $(top_srcdir)/backends/eds/lib/*.vala
folks_eds_doc_deps = \
	gmodule-2.0 \
	gio-2.0 \
	gee-0.8 \
	libebook-1.2 \
	libedataserver-1.2 \
	build-conf \
	folks \
	folks-internal \
	folks-generics \
	$(NULL)
valadoc_flags_folks_eds = \
	$(valadoc_flags) \
	-X $(top_srcdir)/backends/eds/lib/folks/folks-eds.h \
	$(addprefix --pkg=,$(folks_eds_doc_deps)) \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/eds/lib \
	$(folks_eds_doc_files) \
	$(NULL)

folks-eds-doc.stamp: $(folks_eds_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-o folks-eds/ \
		--doclet=devhelp \
		$(valadoc_flags_folks_eds) \
		$(NULL)
	@touch $@

folks-eds-gtk-doc.stamp: $(folks_eds_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-X -l -X $(top_builddir)/folks/.libs/libfolks.so \
		-X -l -X $(top_builddir)/backends/eds/lib/.libs/libfolks-eds.so \
		-o gtk-doc/folks-eds \
		--doclet=gtkdoc \
		$(valadoc_flags_folks_eds) \
		$(NULL)
	@touch $@

distclean_dirs += folks-eds
docs += \
	folks-eds-doc \
	folks-eds-gtk-doc \
	$(NULL)
upload_docs += upload-docs-c-folks-eds upload-docs-vala-folks-eds

endif # ENABLE_EDS

#####################
# libsocialweb docs #
#####################
if ENABLE_LIBSOCIALWEB
folkslibsocialwebdocdir=$(datadir)/devhelp/references/folks-libsocialweb
folkslibsocialwebgtkdocdir=$(datadir)/gtk-doc/html/folks-libsocialweb

folkslibsocialwebdoc_DATA = \
	folks-libsocialweb/folks-libsocialweb/folks-libsocialweb.devhelp2 \
	$(addprefix folks-libsocialweb/folks-libsocialweb/,$(common_doc_files))\
	$(NULL)

folkslibsocialwebgtkdoc_DATA = gtk-doc/folks-libsocialweb/html/*

$(folkslibsocialwebdoc_DATA): \
	folks-libsocialweb-doc.stamp \
	$(NULL)
$(folkslibsocialwebgtkdoc_DATA): folks-libsocialweb-gtk-doc.stamp

folks_libsocialweb_doc_files = $(top_srcdir)/backends/libsocialweb/lib/*.vala
folks_libsocialweb_doc_deps = \
	gmodule-2.0 \
	gio-2.0 \
	gee-0.8 \
	libsocialweb-client \
	build-conf \
	folks \
	folks-internal \
	folks-generics \
	$(NULL)
valadoc_flags_folks_libsocialweb = \
	$(valadoc_flags) \
	-X $(top_srcdir)/backends/libsocialweb/lib/folks/folks-libsocialweb.h \
	$(addprefix --pkg=,$(folks_libsocialweb_doc_deps)) \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/libsocialweb/lib \
	$(folks_libsocialweb_doc_files) \
	$(NULL)

folks-libsocialweb-doc.stamp: $(folks_libsocialweb_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-o folks-libsocialweb/ \
		--doclet=devhelp \
		$(valadoc_flags_folks_libsocialweb) \
		$(NULL)
	@touch $@

folks-libsocialweb-gtk-doc.stamp: $(folks_libsocialweb_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-X -l -X $(top_builddir)/folks/.libs/libfolks.so \
		-X -l -X $(top_builddir)/backends/libsocialweb/lib/.libs/libfolks-libsocialweb.so \
		-o gtk-doc/folks-libsocialweb \
		--doclet=gtkdoc \
		$(valadoc_flags_folks_libsocialweb) \
		$(NULL)
	@touch $@

distclean_dirs += folks-libsocialweb
docs += \
	folks-libsocialweb-doc \
	folks-libsocialweb-gtk-doc \
	$(NULL)
upload_docs += \
	upload-docs-c-folks-libsocialweb \
	upload-docs-vala-folks-libsocialweb \
	$(NULL)

endif # ENABLE_LIBSOCIALWEB

#####################
# end optional docs #
#####################

stamps = $(addsuffix .stamp, $(docs))

all: $(stamps)

CLEANFILES = $(stamps)

doc_host = telepathy.freedesktop.org
doc_host_dir = /srv/telepathy.freedesktop.org/www/doc

upload-docs-check-%: %
	ssh $(doc_host) "test -e $(doc_host_dir)/$< || mkdir $(doc_host_dir)/$<"

# adapted from telepathy-glib
upload-docs-c-%: gtk-doc/% upload-docs-check-%
	rsync -rvzPp --chmod=Dg+s,ug+rwX,o=rX $(top_srcdir)/docs/$</html/ \
		$(doc_host):$(doc_host_dir)/$(<F)/c

upload-docs-vala-%: % upload-docs-check-%
	rsync -rvzPp --chmod=Dg+s,ug+rwX,o=rX $(top_srcdir)/docs/$</$</ \
		$(doc_host):$(doc_host_dir)/$</vala

maintainer-upload-release: _maintainer-upload-release-local
_maintainer-upload-release-local: $(upload_docs)

distclean-local: distclean-docs
distclean-docs:
	rm -rf $(distclean_dirs)

GITIGNOREFILES = \
	folks/ \
	folks-eds/ \
	folks-libsocialweb/ \
	folks-telepathy/ \
	gtk-doc/ \
	$(NULL)

-include $(top_srcdir)/git.mk
