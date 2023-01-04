# Evolution-Data-Server (E-D-S) backend
eds_backend_name = 'eds'

# Backend library
subdir('lib')

eds_backend_sources = [
  'eds-backend-factory.vala',
  'eds-backend.vala',
]

eds_backend_deps = [
  backend_deps,
  libebook_dep,
  libedataserver_dep,
  eds_backendlib_dep,
]

eds_backend_vala_flags = [
]

eds_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(eds_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(eds_backend_name),
]

eds_backend = shared_module('eds',
  eds_backend_sources,
  dependencies: eds_backend_deps,
  vala_args: eds_backend_vala_flags,
  c_args: eds_backend_c_flags,
  name_prefix: '',
  install_dir: folks_backend_dir / eds_backend_name,
  install: true,
)

folks_backends += eds_backend
