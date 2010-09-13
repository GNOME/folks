folksdocdir=$(datadir)/devhelp/references/folks-@FOLKS_MAJOR_MINOR_VERSION@
folksinnerdocdir=$(datadir)/devhelp/references/folks-@FOLKS_MAJOR_MINOR_VERSION@/folks-@FOLKS_MAJOR_MINOR_VERSION@
folksimgdir=$(datadir)/devhelp/references/folks-@FOLKS_MAJOR_MINOR_VERSION@/folks-@FOLKS_MAJOR_MINOR_VERSION@/img
folkstpdocdir=$(datadir)/devhelp/references/folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@
folkstpinnerdocdir=$(datadir)/devhelp/references/folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@
folkstpimgdir=$(datadir)/devhelp/references/folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/img

folksdoc_data = \
	folks-@FOLKS_MAJOR_MINOR_VERSION@/*.css \
	folks-@FOLKS_MAJOR_MINOR_VERSION@/*.png \
	$(NULL)
folkstpdoc_data = \
	folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/*.css \
	folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/*.png \
	$(NULL)

folksdoc_DATA = \
	folks-@FOLKS_MAJOR_MINOR_VERSION@/index.html \
	$(folksdoc_data) \
	$(NULL)
folkstpdoc_DATA = \
	folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/index.html \
	$(folkstpdoc_data) \
	$(NULL)

folksinnerdoc_DATA = \
	folks-@FOLKS_MAJOR_MINOR_VERSION@/folks-@FOLKS_MAJOR_MINOR_VERSION@/index.htm \
	folks-@FOLKS_MAJOR_MINOR_VERSION@/folks-@FOLKS_MAJOR_MINOR_VERSION@/*.html \
	$(NULL)
folkstpinnerdoc_DATA = \
	folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/index.htm \
	folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/*.html \
	$(NULL)

folksimg_DATA = \
	folks-@FOLKS_MAJOR_MINOR_VERSION@/folks-@FOLKS_MAJOR_MINOR_VERSION@/img/*.png \
	$(NULL)
folkstpimg_DATA = \
	folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/img/*.png \
	$(NULL)

$(folksdoc_data) $(folksinnerdoc_DATA) $(folksimg_DATA): folks-@FOLKS_MAJOR_MINOR_VERSION@/index.html
$(folkstpdoc_data) $(folkstpinnerdoc_DATA) $(folkstpimg_DATA): folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/index.html

# folks documentation
folks_doc_files = $(top_srcdir)/folks/*.vala

folks-@FOLKS_MAJOR_MINOR_VERSION@/index.html: $(folks_doc_files)
	$(AM_V_GEN)$(VALADOC) -o folks-@FOLKS_MAJOR_MINOR_VERSION@/ --force -b $(top_srcdir)/folks \
		--pkg=gee-1.0 --pkg=gio-2.0 --pkg=gmodule-2.0 --pkg=build-conf \
		--vapidir=$(top_srcdir)/folks $(folks_doc_files)

# folks-telepathy documentation
folks_telepathy_doc_files = $(top_srcdir)/backends/telepathy/lib/*.vala

folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/index.html: $(folks_telepathy_doc_files)
	$(AM_V_GEN)$(VALADOC) -o folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/ \
		--force -b $(top_srcdir)/backends/telepathy/lib \
		--pkg=gee-1.0 --pkg=gio-2.0 --pkg=gmodule-2.0 --pkg=build-conf \
		--pkg=dbus-glib-1 --pkg=telepathy-glib --pkg=tp-lowlevel \
		--pkg=folks \
		--vapidir=$(top_srcdir)/folks \
		--vapidir=$(top_srcdir)/backends/telepathy/lib \
		$(folks_telepathy_doc_files)

distclean-local: distclean-docs
distclean-docs:
	rm -rf folks-@FOLKS_MAJOR_MINOR_VERSION@ && \
	rm -rf folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@

GITIGNOREFILES = \
	folks-@FOLKS_MAJOR_MINOR_VERSION@/ \
	folks-telepathy-@FOLKS_MAJOR_MINOR_VERSION@/ \
	$(NULL)

-include $(top_srcdir)/git.mk
