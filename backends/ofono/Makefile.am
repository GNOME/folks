include $(top_srcdir)/backends/backend.mk
BACKEND_NAME = "ofono"

backenddir = $(BACKEND_DIR)/ofono
backend_LTLIBRARIES = ofono.la

# FIXME: libedataserver-1.2 doesn't need to be explicitly mentioned
# once we depend on a libebook version that includes libedataserver-1.2
# in libebook-1.2.deps.
ofono_la_VALAFLAGS = \
	$(backend_valaflags) \
	--pkg folks-generics \
	--pkg libebook-1.2 \
	--pkg libedataserver-1.2 \
	$(NULL)

ofono_la_SOURCES = \
	$(backend_sources) \
	ofono-backend.vala \
	ofono-backend-factory.vala \
	ofono-persona.vala \
	ofono-persona-store.vala \
	org-ofono.vala \
	$(NULL)

ofono_la_CPPFLAGS = \
	$(backend_cppflags) \
	$(NULL)

ofono_la_CFLAGS = \
	$(backend_cflags) \
	$(EBOOK_CFLAGS) \
	$(NULL)

ofono_la_LIBADD = \
	$(backend_libadd) \
	$(EBOOK_LIBS) \
	$(NULL)

ofono_la_LDFLAGS = \
	-module -avoid-version \
	$(backend_ldflags) \
	$(NULL)

-include $(top_srcdir)/git.mk
