gtkdocentities_in = files('gtkdocentities.ent.in')

# Build the gtkdoc documentation for libfolks and each backend library
foreach doc_target : valadoc_targets
  doc_name = doc_target.get('name')

  # Meson doesn't allow subdirectories in configure_file, so we have to
  # generate each gtkdocentities.ent in their respective subfolder, at the
  # place gtk-doc magically expects it to be
  subdir(doc_name / 'xml')

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
      '-X', meson.project_build_root() / 'folks' / 'folks' / 'folks.h',
      '@INPUT@',
    ],
    depends: doc_target.get('library'),
    install: true,
    install_dir: get_option('datadir') / 'gtk-doc' / 'html',
  )
endforeach
