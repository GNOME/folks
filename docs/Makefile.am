distclean_dirs = \
	folks \
	folks-telepathy \
	gtk-doc \
	$(NULL)

phony_deps = \
	folks-doc \
	folks-gtk-doc \
	folks-telepathy-doc \
	folks-telepathy-gtk-doc \
	$(NULL)

upload_docs = \
	upload-docs-c-folks \
	upload-docs-vala-folks \
	upload-docs-c-folks-telepathy \
	upload-docs-vala-folks-telepathy \
	$(NULL)

folksdocdir=$(datadir)/devhelp/references/folks
folksimgdir=$(datadir)/devhelp/references/folks/img
folkstelepathydocdir=$(datadir)/devhelp/references/folks-telepathy
folkstelepathyimgdir=$(datadir)/devhelp/references/folks-telepathy/img

folksgtkdocdir=$(datadir)/gtk-doc/html/folks
folkstelepathygtkdocdir=$(datadir)/gtk-doc/html/folks-telepathy

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
folkstelepathydoc_DATA = \
	folks-telepathy/folks-telepathy/folks-telepathy.devhelp2 \
	$(addprefix folks-telepathy/folks-telepathy/,$(common_doc_files)) \
	$(NULL)

folksgtkdoc_DATA = gtk-doc/folks/html/*
folkstelepathygtkdoc_DATA = gtk-doc/folks-telepathy/html/*

folksimg_DATA = \
	folks/folks/img/*.png \
	$(NULL)
folkstelepathyimg_DATA = \
	folks-telepathy/folks-telepathy/img/*.png \
	$(NULL)

$(folksdoc_DATA) $(folksimg_DATA): folks-doc
$(folkstelepathydoc_DATA) $(folkstelepathyimg_DATA): folks-telepathy-doc
$(folksgtkdoc_DATA): folks-gtk-doc
$(folkstelepathygtkdoc_DATA): folks-telepathy-gtk-doc

valadoc_flags = \
	--force \
	--package-version $(PACKAGE_VERSION) \
	$(NULL)

# folks documentation
folks_doc_files_blacklist = \
	$(top_srcdir)/folks/internal.vala \
	$(NULL)
# this expands the list of files, so we can filter out elements
folks_doc_files_all = \
	$(wildcard $(top_srcdir)/folks/*.vala) \
	$(NULL)
# FIXME: sort the files manually to work around the native doclet portion of
# bgo#662784
folks_doc_files = \
	$(sort \
	$(filter-out $(folks_doc_files_blacklist),$(folks_doc_files_all)))
folks_doc_deps = \
	gmodule-2.0 \
	gio-2.0 \
	gee-1.0 \
	folks-internal \
	build-conf \
	$(NULL)
valadoc_flags_folks = \
	$(valadoc_flags) \
	-X $(top_srcdir)/folks/folks.h \
	$(addprefix --pkg=,$(folks_doc_deps)) \
	--vapidir=$(top_srcdir)/folks \
	$(folks_doc_files) \
	$(NULL)

folks-doc: $(folks_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-o folks/ \
		--doclet=devhelp \
		$(valadoc_flags_folks) \
		$(NULL)

folks-gtk-doc: $(folks_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-X -l -X $(top_builddir)/folks/.libs/libfolks.so \
		-o gtk-doc/folks \
		--doclet=gtkdoc \
		$(valadoc_flags_folks) \
		$(NULL)

# folks-telepathy documentation
folks_telepathy_doc_files = $(top_srcdir)/backends/telepathy/lib/*.vala
folks_telepathy_doc_deps = \
	gmodule-2.0 \
	gio-2.0 \
	gee-1.0 \
	telepathy-glib \
	zeitgeist-1.0 \
	tp-lowlevel \
	build-conf \
	folks \
	folks-internal \
	$(NULL)
valadoc_flags_folks_telepathy = \
	$(valadoc_flags) \
	-X $(top_srcdir)/backends/telepathy/lib/folks/folks-telepathy.h \
	$(addprefix --pkg=,$(folks_telepathy_doc_deps)) \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/telepathy/lib \
	$(folks_telepathy_doc_files) \
	$(NULL)

folks-telepathy-doc: $(folks_telepathy_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-o folks-telepathy/ \
		--doclet=devhelp \
		$(valadoc_flags_folks_telepathy) \
		$(NULL)

folks-telepathy-gtk-doc: $(folks_telepathy_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-X -l -X $(top_builddir)/folks/.libs/libfolks.so \
		-X -l -X $(top_builddir)/backends/telepathy/lib/.libs/libfolks-telepathy.so \
		-X --ignore-headers -X $(top_srcdir)/backends/telepathy/lib/tp-lowlevel.h \
		-o gtk-doc/folks-telepathy \
		--doclet=gtkdoc \
		$(valadoc_flags_folks_telepathy) \
		$(NULL)

#####################
# EDS docs #
#####################
if ENABLE_EDS
folksedsdocdir=$(datadir)/devhelp/references/folks-eds
folksedsimgdir=$(datadir)/devhelp/references/folks-eds/img
folksedsgtkdocdir=$(datadir)/gtk-doc/html/folks-eds

folksedsdoc_DATA = \
	folks-eds/folks-eds/folks-eds.devhelp2 \
	$(addprefix folks-eds/folks-eds/,$(common_doc_files))\
	$(NULL)

folksedsgtkdoc_DATA = gtk-doc/folks-eds/html/*

folksedsimg_DATA = \
	folks-eds/folks-eds/img/*.png \
	$(NULL)

$(folksedsdoc_DATA) $(folksedsimg_DATA): \
	folks-eds-doc \
	$(NULL)
$(folksedsgtkdoc_DATA): folks-eds-gtk-doc

folks_eds_doc_files = $(top_srcdir)/backends/eds/lib/*.vala
folks_eds_doc_deps = \
	gmodule-2.0 \
	gio-2.0 \
	gee-1.0 \
	libebook-1.2 \
	libedataserver-1.2 \
	build-conf \
	folks \
	folks-internal \
	$(NULL)
valadoc_flags_folks_eds = \
	$(valadoc_flags) \
	-X $(top_srcdir)/backends/eds/lib/folks/folks-eds.h \
	$(addprefix --pkg=,$(folks_eds_doc_deps)) \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/eds/lib \
	$(folks_eds_doc_files) \
	$(NULL)

folks-eds-doc: $(folks_eds_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-o folks-eds/ \
		--doclet=devhelp \
		$(valadoc_flags_folks_eds) \
		$(NULL)

folks-eds-gtk-doc: $(folks_eds_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-X -l -X $(top_builddir)/folks/.libs/libfolks.so \
		-X -l -X $(top_builddir)/backends/eds/lib/.libs/libfolks-eds.so \
		-o gtk-doc/folks-eds \
		--doclet=gtkdoc \
		$(valadoc_flags_folks_eds) \
		$(NULL)

distclean_dirs += folks-eds
phony_deps += \
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
folkslibsocialwebimgdir=$(datadir)/devhelp/references/folks-libsocialweb/img
folkslibsocialwebgtkdocdir=$(datadir)/gtk-doc/html/folks-libsocialweb

folkslibsocialwebdoc_DATA = \
	folks-libsocialweb/folks-libsocialweb/folks-libsocialweb.devhelp2 \
	$(addprefix folks-libsocialweb/folks-libsocialweb/,$(common_doc_files))\
	$(NULL)

folkslibsocialwebgtkdoc_DATA = gtk-doc/folks-libsocialweb/html/*

folkslibsocialwebimg_DATA = \
	folks-libsocialweb/folks-libsocialweb/img/*.png \
	$(NULL)

$(folkslibsocialwebdoc_DATA) $(folkslibsocialwebimg_DATA): \
	folks-libsocialweb-doc \
	$(NULL)
$(folkslibsocialwebgtkdoc_DATA): folks-libsocialweb-gtk-doc

folks_libsocialweb_doc_files = $(top_srcdir)/backends/libsocialweb/lib/*.vala
folks_libsocialweb_doc_deps = \
	gmodule-2.0 \
	gio-2.0 \
	gee-1.0 \
	libsocialweb-client \
	build-conf \
	folks \
	folks-internal \
	$(NULL)
valadoc_flags_folks_libsocialweb = \
	$(valadoc_flags) \
	-X $(top_srcdir)/backends/libsocialweb/lib/folks/folks-libsocialweb.h \
	$(addprefix --pkg=,$(folks_libsocialweb_doc_deps)) \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/libsocialweb/lib \
	$(folks_libsocialweb_doc_files) \
	$(NULL)

folks-libsocialweb-doc: $(folks_libsocialweb_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-o folks-libsocialweb/ \
		--doclet=devhelp \
		$(valadoc_flags_folks_libsocialweb) \
		$(NULL)

folks-libsocialweb-gtk-doc: $(folks_libsocialweb_doc_files)
	$(AM_V_GEN)$(VALADOC) \
		-X -l -X $(top_builddir)/folks/.libs/libfolks.so \
		-X -l -X $(top_builddir)/backends/libsocialweb/lib/.libs/libfolks-libsocialweb.so \
		-o gtk-doc/folks-libsocialweb \
		--doclet=gtkdoc \
		$(valadoc_flags_folks_libsocialweb) \
		$(NULL)

distclean_dirs += folks-libsocialweb
phony_deps += \
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

.PHONY: $(phony_deps)

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
