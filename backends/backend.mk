#
# Common build variable values for folks backends.
#
# Required variables:
#  - BACKEND_NAME = "name-of-backend"
#    (this must be the same as the source directory and the backend's type ID)
# Required targets:
#  - $(BACKEND_NAME).la
# Defined variables (these must be included in the backend-specific variables):
#  - backend_sources
#  - backend_valaflags
#  - backend_cppflags
#  - backend_cflags
#  - backend_libadd
#  - backend_ldflags
# The defined variables include flags for the standard dependencies:
#  - folks
#  - GIO
#  - GLib
#  - libgee
# and also include the relevant $(AM_*) variables.
#
# Note: It is suggested that Makefile.ams include the flags
# '-module -avoid-version' in their *_LDFLAGS variable, as well as in
# $(backend_ldflags). This shuts up automake's warnings about the library name
# not being prefixed by 'lib'.

# Added in case it's needed in the future.
backend_sources = \
	$(NULL)

backend_valaflags = \
	$(AM_VALAFLAGS) \
	$(TARGET_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_builddir)/folks \
	--pkg folks \
	--pkg folks-internal \
	--pkg folks-generics \
	--pkg gee-0.8 \
	--pkg gio-2.0 \
	--pkg gobject-2.0 \
	$(NULL)

backend_cppflags = \
	$(AM_CPPFLAGS) \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-include $(top_srcdir)/folks/warnings.h \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

backend_cflags = \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

backend_libadd = \
	$(AM_LIBADD) \
	$(top_builddir)/folks/libfolks.la \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

backend_ldflags = \
	$(AM_LDFLAGS) \
	$(CODE_COVERAGE_LDFLAGS) \
	-shared \
	-fPIC \
	-module \
	-avoid-version \
	-no-undefined \
	$(NULL)
