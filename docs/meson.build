# Specify some common flags
docs_common_valadoc_flags = [
  '--force',
  '--package-version', meson.project_version(),
  '--no-protected',
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

# Now build the documentation for each library
foreach doc_target : valadoc_targets
  doc_name = doc_target[0]
  doc_source_files = doc_target[1]
  doc_library = doc_target[2]
  doc_deps = doc_target[3]

  # First, the valadoc module
  valadoc_output_dir = doc_name + '-valadoc'
  doc_valadoc = custom_target(doc_name + '-valadoc',
    input: doc_source_files,
    output: valadoc_output_dir,
    command: [ valadoc,
      '-o', meson.current_build_dir() / valadoc_output_dir,
      docs_common_valadoc_flags,
      docs_common_valadoc_deps,
      doc_deps,
      '--doclet=devhelp',
      '--wiki=@0@'.format(meson.current_source_dir() / 'wiki'),
      '@INPUT@',
    ],
    depends: doc_library,
    install: true,
    install_dir: get_option('datadir') / 'devhelp' / 'references' / doc_name,
  )

  # Second, the gtk-doc module
  gtkdoc_output_dir = doc_name + '-gtkdoc'
  doc_gtkdoc = custom_target(doc_name + '-gtkdoc',
    input: doc_source_files,
    output: gtkdoc_output_dir,
    command: [ valadoc,
      '-X', meson.build_root() / 'folks' / 'folks.h',
      '-o', meson.current_build_dir() / gtkdoc_output_dir,
      docs_common_valadoc_flags,
      docs_common_valadoc_deps,
      doc_deps,
      '--doclet=gtkdoc',
      '@INPUT@',
    ],
    depends: doc_library,
    install: true,
    install_dir: get_option('datadir') / 'gtk-doc' / 'html' / doc_name,
  )
endforeach
