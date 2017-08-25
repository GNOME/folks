# Backend library
subdir('lib')

# Backend itself
libsocialweb_backend_name = 'libsocialweb'

libsocialweb_backend_sources = [
  'sw-backend-factory.vala',
  'sw-backend.vala',
]

libsocialweb_backend_deps = [
  backend_deps,
  folks_libsocialweb_backend_dep,
]

libsocialweb_backend_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

libsocialweb_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(libsocialweb_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(libsocialweb_backend_name),
]

libsocialweb_backend = library(libsocialweb_backend_name,
  libsocialweb_backend_sources,
  dependencies: libsocialweb_backend_deps,
  vala_args: libsocialweb_backend_vala_flags,
  c_args: libsocialweb_backend_c_flags,
  link_with: libfolks_internal,
)

folks_backends += libsocialweb_backend
