folks_eds_backend_sources = [
  'edsf-persona-store.vala',
  'edsf-persona.vala',
]

folks_eds_backend_deps = [
  backend_deps,
  libebook,
  libebook_contacts,
  libedataserver,
  libxml,
]

folks_eds_backend_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

folks_eds_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(folks_eds_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(folks_eds_backend_name),
]

folks_eds_backend = library('folks-@0@'.format(folks_eds_backend_name),
  folks_eds_backend_sources,
  dependencies: folks_eds_backend_deps,
  vala_args: folks_eds_backend_vala_flags,
  c_args: folks_eds_backend_c_flags,
  link_with: libfolks_internal,
  version: folks_eds_lib_version,
  vala_gir: 'FolksEds-@0@.gir'.format(folks_api_version),
  install: true,
  install_dir: [ true, folks_headers_install_dir, true, true ],
)

folks_eds_backend_dep = declare_dependency(
  link_with: folks_eds_backend,
  include_directories: include_directories('.'),
)

# Pkg-config file
configure_file(
  input: 'folks-eds.pc.in',
  output: 'folks-eds.pc',
  configuration: pkg_conf,
  install_dir: pkg_install_dir,
)
