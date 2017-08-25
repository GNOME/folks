# Backend library
subdir('lib')

# Backend itself
folks_eds_backend_name = 'eds'

folks_eds_backend_sources = [
  'eds-backend-factory.vala',
  'eds-backend.vala',
]

folks_eds_backend_deps = [
  backend_deps,
  libebook,
  libedataserver,
  folks_eds_backend_dep,
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

folks_eds_backend = library('eds',
  folks_eds_backend_sources,
  dependencies: folks_eds_backend_deps,
  vala_args: folks_eds_backend_vala_flags,
  c_args: folks_eds_backend_c_flags,
  link_with: libfolks_internal,
)

folks_backends += folks_eds_backend
