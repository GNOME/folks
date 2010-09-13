docdir=$(datadir)/devhelp/references/folks-@FOLKS_MAJOR_MINOR_VERSION@
innerdocdir=$(datadir)/devhelp/references/folks-@FOLKS_MAJOR_MINOR_VERSION@/folks-@FOLKS_MAJOR_MINOR_VERSION@
imgdir=$(datadir)/devhelp/references/folks-@FOLKS_MAJOR_MINOR_VERSION@/folks-@FOLKS_MAJOR_MINOR_VERSION@/img

doc_data = \
	folks-@FOLKS_MAJOR_MINOR_VERSION@/*.css \
	folks-@FOLKS_MAJOR_MINOR_VERSION@/*.png \
	$(NULL)

doc_DATA = \
	folks-@FOLKS_MAJOR_MINOR_VERSION@/index.html \
	$(doc_data) \
	$(NULL)

innerdoc_DATA = \
	folks-@FOLKS_MAJOR_MINOR_VERSION@/folks-@FOLKS_MAJOR_MINOR_VERSION@/index.htm \
	folks-@FOLKS_MAJOR_MINOR_VERSION@/folks-@FOLKS_MAJOR_MINOR_VERSION@/*.html \
	$(NULL)

img_DATA = \
	folks-@FOLKS_MAJOR_MINOR_VERSION@/folks-@FOLKS_MAJOR_MINOR_VERSION@/img/*.png \
	$(NULL)

$(doc_data) $(innerdoc_DATA) $(img_DATA): folks-@FOLKS_MAJOR_MINOR_VERSION@/index.html

VALAFLAGS = \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/telepathy \
	--vapidir=$(top_srcdir)/backends/telepathy/lib

# The Vala files which will have documentation extracted from them
_doc_files = \
	$(top_srcdir)/folks/*.vala \
	$(top_srcdir)/backends/telepathy/*.vala \
	$(top_srcdir)/backends/telepathy/lib/*.vala \
	$(top_srcdir)/backends/key-file/*.vala
doc_files = $(filter-out %-backend-factory.vala,$(wildcard $(_doc_files)))

folks-@FOLKS_MAJOR_MINOR_VERSION@/index.html: $(doc_files)
	$(AM_V_GEN)$(VALADOC) -o folks-@FOLKS_MAJOR_MINOR_VERSION@/ --force -b $(top_srcdir) \
		--pkg=gee-1.0 --pkg=gio-2.0 --pkg=gmodule-2.0 --pkg=build-conf \
		--pkg=dbus-glib-1 --pkg=telepathy-glib --pkg=tp-lowlevel \
		$(VALAFLAGS) $(doc_files)

distclean-local: distclean-docs
distclean-docs:
	rm -rf folks-@FOLKS_MAJOR_MINOR_VERSION@

GITIGNOREFILES = folks-@FOLKS_MAJOR_MINOR_VERSION@/

-include $(top_srcdir)/git.mk
