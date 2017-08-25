folks_dummy_backend_name = 'folks-dummy'

folks_dummy_backend_sources = [
  'dummy-backend.vala',
  'dummy-full-persona.vala',
  'dummy-persona-store.vala',
  'dummy-persona.vala',
]

folks_dummy_backend_deps = [
  backend_deps,
]

folks_dummy_backend_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

folks_dummy_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(folks_dummy_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(folks_dummy_backend_name),
]

folks_dummy_backend = library(folks_dummy_backend_name,
  folks_dummy_backend_sources,
  dependencies: folks_dummy_backend_deps,
  vala_args: folks_dummy_backend_vala_flags,
  c_args: folks_dummy_backend_c_flags,
  link_with: libfolks_internal,
)

folks_dummy_backend_dep = declare_dependency(
  link_with: folks_dummy_backend,
  include_directories: include_directories('.'),
)

# Pkg-config file
configure_file(
  input: 'folks-dummy.pc.in',
  output: 'folks-dummy.pc',
  configuration: pkg_conf,
  install_dir: pkg_install_dir,
)
