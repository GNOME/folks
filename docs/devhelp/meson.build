# Build the devhelp documentation for libfolks and each backend library
foreach doc_target : valadoc_targets
  doc_name = doc_target.get('name')

  doc_valadoc = gnome.valadoc(
    package_name: doc_name,
    package_version: meson.project_version(),
    sources: doc_target.get('source_files'),
    doclet: 'devhelp',
    wiki_dir: meson.current_source_dir() / '..' / 'wiki',
    # XXX do we need to pass on these dependencies somehow?
    # depends: doc_target.get('library'),
    packages: docs_common_valadoc_deps + doc_target.get('dependencies'),
    install: true,
    install_dir: get_option('datadir') / 'devhelp' / 'books',
  )
endforeach
