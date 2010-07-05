docdir=$(datadir)/devhelp/references/folks-0.1
innerdocdir=$(datadir)/devhelp/references/folks-0.1/folks-0.1
imgdir=$(datadir)/devhelp/references/folks-0.1/folks-0.1/img

doc_data = \
	folks-0.1/*.css \
	folks-0.1/*.png \
	$(NULL)

doc_DATA = \
	folks-0.1/index.html \
	$(doc_data) \
	$(NULL)

innerdoc_DATA = \
	folks-0.1/folks-0.1/index.htm \
	folks-0.1/folks-0.1/*.html \
	$(NULL)

img_DATA = \
	folks-0.1/folks-0.1/img/*.png \
	$(NULL)

$(doc_data) $(innerdoc_DATA) $(img_DATA): folks-0.1/index.html

VALAFLAGS = --vapidir=$(top_srcdir)/folks --vapidir=$(top_srcdir)/backends/telepathy
VALAFLAGS += $(shell PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) pkg-config --variable=valaflags telepathy-vala)

# The Vala files which will have documentation extracted from them
doc_files = $(top_srcdir)/folks/*.vala $(top_srcdir)/backends/telepathy/*.vala

folks-0.1/index.html: $(doc_files)
	$(VALADOC) -o folks-0.1/ --force -b $(top_srcdir) \
		--pkg=gee-1.0 --pkg=gio-2.0 --pkg=gmodule-2.0 --pkg=build-conf \
		--pkg=dbus-glib-1 --pkg=telepathy-glib --pkg=tp-lowlevel \
		$(VALAFLAGS) $(doc_files)

distclean-local: distclean-docs
distclean-docs:
	cd $(srcdir) && rm -rf folks-0.1

