# Build the gtkdoc documentation for libfolks and each backend library
foreach doc_target : valadoc_targets
  doc_name = doc_target.get('name')

  doc_gtkdoc = custom_target(doc_name + '-gtkdoc',
    input: doc_target.get('source_files'),
    output: doc_name,
    command: [ valadoc,
      '--doclet=gtkdoc',
      '--directory', '@OUTDIR@' / doc_name,
      '--package-name', doc_name,
      docs_common_valadoc_flags,
      docs_common_valadoc_deps,
      doc_target.get('dependencies'),
      '-X', meson.build_root() / 'folks' / 'folks' / 'folks.h',
      '@INPUT@',
     ],
    depends: doc_target.get('library'),
    install: true,
    install_dir: get_option('datadir') / 'gtk-doc' / 'html',
  )
endforeach
