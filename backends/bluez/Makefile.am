include $(top_srcdir)/backends/backend.mk
BACKEND_NAME = "bluez"

backenddir = $(BACKEND_DIR)/bluez
backend_LTLIBRARIES = bluez.la

bluez_la_VALAFLAGS = \
	$(backend_valaflags) \
	--pkg libebook-1.2 \
	--pkg folks-generics \
	$(NULL)

bluez_la_SOURCES = \
	$(backend_sources) \
	bluez-backend.vala \
	bluez-backend-factory.vala \
	bluez-persona.vala \
	bluez-persona-store.vala \
	org-bluez-obex-client.vala \
	org-bluez.vala \
	$(NULL)

bluez_la_CPPFLAGS = \
	$(backend_cppflags) \
	$(NULL)

bluez_la_CFLAGS = \
	$(backend_cflags) \
	$(EBOOK_CFLAGS) \
	$(NULL)

bluez_la_LIBADD = \
	$(backend_libadd) \
	$(EBOOK_LIBS) \
	$(LIBM) \
	$(NULL)

bluez_la_LDFLAGS = \
	-module -avoid-version \
	$(backend_ldflags) \
	$(NULL)

-include $(top_srcdir)/git.mk
