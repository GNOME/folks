# Specify some common flags
docs_common_valadoc_flags = [
  '--force',
  '--package-version', meson.project_version(),
  '--no-protected',
  '-X', meson.build_root() / 'folks' / 'folks.h',
]

docs_common_valadoc_deps = [
  '--pkg', 'gmodule-2.0',
  '--pkg', 'glib-2.0',
  '--pkg', 'gio-2.0',
  '--pkg', 'gee-0.8',
  '--vapidir', meson.build_root() / 'folks',
  '--pkg', 'folks-internal',
  '--vapidir', meson.source_root() / 'folks',
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

# The modules we should build for
valadoc_targets = [
  [ 'folks',       libfolks_sources,         libfolks_lib,     []                        ],
  [ 'folks-dummy', dummy_backendlib_sources, dummy_backendlib, dummy_backendlib_doc_deps ],
]

if eds_backend_enabled
  valadoc_targets += [[ 'folks-eds', eds_backendlib_sources, eds_backendlib, eds_backendlib_doc_deps ]]
endif

if libsocialweb_backend_enabled
  valadoc_targets += [[ 'folks-libsocialweb', libsocialweb_backendlib_sources, libsocialweb_backendlib, libsocialweb_backendlib_doc_deps ]]
endif

if telepathy_backend_enabled
  valadoc_targets += [[ 'folks-telepathy', telepathy_backendlib_sources, telepathy_backendlib, telepathy_backendlib_doc_deps ]]
endif

if tracker_backend_enabled
  valadoc_targets += [[ 'folks-tracker', tracker_backendlib_sources, tracker_backendlib, tracker_backendlib_doc_deps ]]
endif

# First, the devhelp modules
subdir('devhelp')

# Second, the gtk-doc module
# FIXME: for some reason, this is broken due to the gtkdoc module not finding
# the folks header
# subdir('gtkdoc')
