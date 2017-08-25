# Build the devhelp documentation for libfolks and each backend library
foreach doc_target : valadoc_targets
  doc_name = doc_target[0]
  doc_source_files = doc_target[1]
  doc_library = doc_target[2]
  doc_deps = doc_target[3]

  doc_valadoc = custom_target(doc_name + '-valadoc',
    input: doc_source_files,
    output: doc_name,
    command: [ valadoc,
      '-o', meson.current_build_dir() / doc_name,
      docs_common_valadoc_flags,
      docs_common_valadoc_deps,
      doc_deps,
      '--doclet=devhelp',
      '--wiki=@0@'.format(meson.current_source_dir() / '..' / 'wiki'),
      '@INPUT@',
    ],
    depends: doc_library,
    install: true,
    install_dir: get_option('datadir') / 'devhelp' / 'references',
  )
endforeach
