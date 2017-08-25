folks_keyfile_backend_name = 'key-file'

folks_keyfile_backend_sources = [
  'kf-backend-factory.vala',
  'kf-backend.vala',
  'kf-persona-store.vala',
  'kf-persona.vala',
]

folks_keyfile_backend_deps = [
  backend_deps,
]

folks_keyfile_backend_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

folks_keyfile_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(folks_keyfile_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(folks_keyfile_backend_name),
]

folks_keyfile_backend = library(folks_keyfile_backend_name,
  folks_keyfile_backend_sources,
  dependencies: folks_keyfile_backend_deps,
  vala_args: folks_keyfile_backend_vala_flags,
  c_args: folks_keyfile_backend_c_flags,
  link_with: libfolks_internal,
)

folks_backends += folks_keyfile_backend
