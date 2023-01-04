# The dummy backend
dummy_backend_name = 'dummy'

# Backend library
subdir('lib')

dummy_backend_sources = [
  'dummy-backend-factory.vala',
]

dummy_backend_deps = [
  backend_deps,
  dummy_backendlib_dep,
]

dummy_backend_vala_flags = [
]

dummy_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(dummy_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(dummy_backend_name),
]

dummy_backend = shared_module(dummy_backend_name,
  dummy_backend_sources,
  dependencies: dummy_backend_deps,
  vala_args: dummy_backend_vala_flags,
  c_args: dummy_backend_c_flags,
  name_prefix: '',
  install_dir: folks_backend_dir / dummy_backend_name,
  install: true,
)

folks_backends += dummy_backend
