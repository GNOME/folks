# Build the devhelp documentation for libfolks and each backend library
foreach doc_target : valadoc_targets
  doc_name = doc_target.get('name')

  doc_valadoc = custom_target(doc_name + '-valadoc',
    input: doc_target.get('source_files'),
    output: doc_name,
    command: [ valadoc,
      '--doclet=devhelp',
      '--directory', '@OUTDIR@',
      '--package-name', doc_name,
      docs_common_valadoc_flags,
      docs_common_valadoc_deps,
      doc_target.get('dependencies'),
      '--wiki=@0@'.format(meson.current_source_dir() / '..' / 'wiki'),
      '@INPUT@',
    ],
    depends: doc_target.get('library'),
    install: true,
    install_dir: get_option('datadir') / 'devhelp' / 'books',
  )
endforeach
