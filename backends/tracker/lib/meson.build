folks_tracker_backend_sources = [
  'trf-persona-store.vala',
  'trf-persona.vala',
  'trf-util.vala',
]

folks_tracker_backend_deps = [
  backend_deps,
  tracker_sparql_dep,
]

folks_tracker_backend_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

folks_tracker_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(folks_tracker_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(folks_tracker_backend_name),
]

folks_tracker_backend = library('folks-@0@'.format(folks_tracker_backend_name),
  folks_tracker_backend_sources,
  dependencies: folks_tracker_backend_deps,
  vala_args: folks_tracker_backend_vala_flags,
  c_args: folks_tracker_backend_c_flags,
  link_with: libfolks_internal,
  version: folks_tracker_lib_version,
  install: true,
  install_dir: [ true, folks_headers_install_dir, true ],
)

folks_tracker_backend_dep = declare_dependency(
  link_with: folks_tracker_backend,
  include_directories: include_directories('.'),
  dependencies: tracker_sparql_dep,
)

# Pkg-config file
configure_file(
  input: 'folks-tracker.pc.in',
  output: 'folks-tracker.pc',
  configuration: pkg_conf,
  install_dir: pkg_install_dir,
)
