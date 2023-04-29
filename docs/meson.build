folks_doc_toml = configure_file(
  input: 'folks.toml.in',
  output: 'folks.toml',
  configuration: {
    'VERSION': meson.project_version(),
  }
)

gidocgen = find_program('gi-docgen', native: true)

custom_target('folks-doc',
  input: [ folks_doc_toml, folks_gir[0] ],
  output: 'folks@0@'.format(folks_api_version),
  command: [
    gidocgen,
    'generate',
    '--quiet',
    '--fatal-warnings',
    '--add-include-path=@0@'.format(meson.current_build_dir() / '../folks'),
    '--config=@INPUT0@',
    '--output-dir=@OUTPUT@',
    '--no-namespace-dir',
    '--content-dir=@0@'.format(meson.current_source_dir()),
    '@INPUT1@',
  ],
  build_by_default: true,
  install: true,
  install_dir: get_option('prefix') / get_option('datadir') / 'doc',
)