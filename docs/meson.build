# Specify some common flags
docs_common_valadoc_flags = [
  '--force',
  '--package-version', meson.project_version(),
  '--no-protected',
]

docs_common_valadoc_deps = [
  '--pkg=gmodule-2.0',
  '--pkg=gio-2.0',
  '--pkg=gee-0.8',
  '--vapidir', meson.build_root() / 'folks',
  '--pkg=folks-internal',
  '--vapidir', meson.source_root() / 'folks',
  '--pkg=folks-generics',
  '--pkg=build-conf',
]

docs_targets = [
  [ 'folks',       libfolks_sources,            libfolks_lib,      ],
  # [ 'folks-dummy', folks_dummy_backend_sources, folks_dummy_backend, ],
]

# Now build the documentation for each library
foreach doc_target : docs_targets
  doc_name = doc_target[0]
  doc_inputs = doc_target[1]
  doc_depends = doc_target[2]

  docs_valadoc_docs = custom_target(doc_name + '-valadoc',
    input: doc_inputs,
    output: doc_name,
    command: [ valadoc,
      '-o', meson.current_build_dir() / doc_name,
      docs_common_valadoc_flags,
      docs_common_valadoc_deps,
      '--doclet=devhelp',
      '--wiki=@0@'.format(meson.current_source_dir() / 'wiki'),
      '@INPUT@',
    ],
    depends: doc_depends,
    install: true,
    install_dir: get_option('datadir') / 'devhelp' / 'books',
  )
endforeach

# TODO also a gtk-doc doclet
# TODO the other libraries
