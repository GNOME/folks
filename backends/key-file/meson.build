keyfile_backend_name = 'key-file'

keyfile_backend_sources = [
  'kf-backend-factory.vala',
  'kf-backend.vala',
  'kf-persona-store.vala',
  'kf-persona.vala',
]

keyfile_backend_deps = [
  backend_deps,
]

keyfile_backend_vala_flags = [
]

keyfile_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(keyfile_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(keyfile_backend_name),
]

keyfile_backend = shared_module(keyfile_backend_name,
  keyfile_backend_sources,
  dependencies: keyfile_backend_deps,
  vala_args: keyfile_backend_vala_flags,
  c_args: keyfile_backend_c_flags,
  name_prefix: '',
  install_dir: folks_backend_dir / keyfile_backend_name,
  install: true,
)

folks_backends += keyfile_backend
