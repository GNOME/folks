# Specify some common flags
docs_common_valadoc_flags = [
  '--force',
  '--package-version', meson.project_version(),
  '--no-protected',
  '-X', meson.build_root() / 'folks' / 'folks' / 'folks.h',
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
  {
    'name': 'folks',
    'source_files': libfolks_sources,
    'library': libfolks_lib,
    'dependencies': [],
  },
  {
    'name': 'folks-dummy',
    'source_files': dummy_backendlib_sources,
    'library': dummy_backendlib,
    'dependencies': dummy_backendlib_doc_deps,
  },
]

if eds_backend_enabled
  valadoc_targets += {
    'name': 'folks-eds',
    'source_files': eds_backendlib_sources,
    'library': eds_backendlib,
    'dependencies': eds_backendlib_doc_deps ,
  }
endif

if telepathy_backend_enabled
  valadoc_targets += {
    'name': 'folks-telepathy',
    'source_files': telepathy_backendlib_sources,
    'library': telepathy_backendlib,
    'dependencies': telepathy_backendlib_doc_deps,
  }
endif

# First, the devhelp modules
subdir('devhelp')

# Second, the gtk-doc module
subdir('gtkdoc')
