folks_libsocialweb_backend_name = 'folks-libsocialweb'

folks_libsocialweb_backend_sources = [
  'swf-persona-store.vala',
  'swf-persona.vala',
]

folks_libsocialweb_backend_deps = [
  backend_deps,
]

folks_libsocialweb_backend_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

folks_libsocialweb_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(folks_libsocialweb_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(folks_libsocialweb_backend_name),
]

folks_libsocialweb_backend = library(folks_libsocialweb_backend_name,
  folks_libsocialweb_backend_sources,
  dependencies: folks_libsocialweb_backend_deps,
  vala_args: folks_libsocialweb_backend_vala_flags,
  c_args: folks_libsocialweb_backend_c_flags,
  link_with: libfolks_internal,
)

folks_libsocialweb_backend_dep = declare_dependency(
  link_with: folks_libsocialweb_backend,
  include_directories: include_directories('.'),
)

# Pkg-config file
configure_file(
  input: 'folks-libsocialweb.pc.in',
  output: 'folks-libsocialweb.pc',
  configuration: pkg_conf,
  install_dir: pkg_install_dir,
)
