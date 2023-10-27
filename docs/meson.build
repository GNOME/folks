# Specify some common flags
docs_common_valadoc_flags = [
  '--force',
  '--package-version', meson.project_version(),
  '--no-protected',
  '-X', meson.project_build_root() / 'folks' / 'folks' / 'folks.h',
]

docs_common_valadoc_deps = [
  'gmodule-2.0',
  'glib-2.0',
  'gio-2.0',
  'gee-0.8',
  # '--vapidir', meson.project_build_root() / 'folks',
  libfolks_internal_dep,
  # '--vapidir', meson.project_source_root() / 'folks',
  # folks_generics_dep,
  # build_conf_dep,
]

# The modules we should build for
valadoc_targets = [
  {
    'name': 'folks',
    'source_files': libfolks_sources,
    'library': libfolks_lib,
    'dependencies': [valac.find_library('folks-generics', dirs: meson.project_source_root() / 'folks')],
  },
  {
    'name': 'folks-dummy',
    'source_files': dummy_backendlib_sources,
    'library': dummy_backendlib,
    'dependencies': dummy_backendlib_doc_deps,
  },
]

if eds_backend_enabled
  if eds_dep.version().version_compare('>=3.41')
    docs_common_valadoc_flags += ['-D', 'HAS_EDS_3_41']
  endif

  if eds_dep.version().version_compare('>=3.59.1')
    docs_common_valadoc_flags += ['-D', 'HAS_EDS_3_60']
  endif

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
# subdir('gtkdoc')
