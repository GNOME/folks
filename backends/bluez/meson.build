folks_bluez_backend_name = 'bluez'

folks_bluez_backend_sources = [
  'bluez-backend-factory.vala',
  'bluez-backend.vala',
  'bluez-persona-store.vala',
  'bluez-persona.vala',
  'org-bluez-obex-client.vala',
  'org-bluez.vala',
]

folks_bluez_backend_deps = [
  backend_deps,
  libfolks_internal_dep,
  libebook,
  libm,
]

folks_bluez_backend_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

folks_bluez_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(folks_bluez_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(folks_bluez_backend_name),
]

folks_bluez_backend = library(folks_bluez_backend_name,
  folks_bluez_backend_sources,
  dependencies: folks_bluez_backend_deps,
  vala_args: folks_bluez_backend_vala_flags,
  c_args: folks_bluez_backend_c_flags,
  name_prefix: '',
  install_dir: join_paths(folks_backend_dir, folks_bluez_backend_name),
  install: true,
)

folks_bluez_backend_dep = declare_dependency(
  link_with: folks_bluez_backend,
  include_directories: include_directories('.'),
)

folks_backends += folks_bluez_backend
