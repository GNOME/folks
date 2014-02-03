include $(top_srcdir)/backends/backend.mk
BACKEND_NAME = "key-file"

backenddir = $(BACKEND_DIR)/key-file
backend_LTLIBRARIES = key-file.la

key_file_la_VALAFLAGS = \
	$(backend_valaflags) \
	--pkg folks-generics \
	$(NULL)

key_file_la_SOURCES = \
	$(backend_sources) \
	kf-backend.vala \
	kf-backend-factory.vala \
	kf-persona.vala \
	kf-persona-store.vala \
	$(NULL)

key_file_la_CPPFLAGS = \
	$(backend_cppflags) \
	$(NULL)

key_file_la_CFLAGS = \
	$(backend_cflags) \
	$(NULL)

key_file_la_LIBADD = \
	$(backend_libadd) \
	$(NULL)

key_file_la_LDFLAGS = \
	-module -avoid-version \
	$(backend_ldflags) \
	$(NULL)

-include $(top_srcdir)/git.mk
