# Backend library
subdir('lib')

# Backend itself
dummy_backend_name = 'dummy'

dummy_backend_sources = [
  'dummy-backend-factory.vala',
]

dummy_backend_deps = [
  backend_deps,
  folks_dummy_backend_dep,
]

dummy_backend_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

dummy_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(dummy_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(dummy_backend_name),
]

dummy_backend = library(dummy_backend_name,
  dummy_backend_sources,
  dependencies: dummy_backend_deps,
  vala_args: dummy_backend_vala_flags,
  c_args: dummy_backend_c_flags,
  link_with: libfolks_internal,
)
