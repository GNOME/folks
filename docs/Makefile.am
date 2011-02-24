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
folks_doc_files = $(top_srcdir)/folks/*.vala
folks_doc_deps = \
	gmodule-2.0 \
	gio-2.0 \
	gee-1.0 \
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
	dbus-glib-1 \
	telepathy-glib \
	tp-lowlevel \
	build-conf \
	folks \
	$(NULL)
valadoc_flags_folks_telepathy = \
	$(valadoc_flags) \
	-X $(top_srcdir)/backends/telepathy/lib/folks-telepathy.h \
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

.PHONY: folks-doc folks-gtk-doc folks-telepathy-doc folks-telepathy-gtk-doc

distclean-local: distclean-docs
distclean-docs:
	rm -rf folks && \
	rm -rf folks-telepathy && \
	rm -rf gtk-doc

GITIGNOREFILES = \
	folks/ \
	folks-telepathy/ \
	gtk-doc/ \
	$(NULL)

-include $(top_srcdir)/git.mk
