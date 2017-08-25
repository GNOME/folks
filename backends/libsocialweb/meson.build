# libsocialweb backend
libsocialweb_backend_name = 'libsocialweb'

# Backend library
subdir('lib')

libsocialweb_backend_sources = [
  'sw-backend-factory.vala',
  'sw-backend.vala',
]

libsocialweb_backend_deps = [
  backend_deps,
  libsocialweb_backendlib_dep,
  libsocialweb_dep,
]

libsocialweb_backend_vala_flags = [
]

libsocialweb_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(libsocialweb_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(libsocialweb_backend_name),
]

libsocialweb_backend = shared_library(libsocialweb_backend_name,
  libsocialweb_backend_sources,
  dependencies: libsocialweb_backend_deps,
  vala_args: libsocialweb_backend_vala_flags,
  c_args: libsocialweb_backend_c_flags,
  name_prefix: '',
  install_dir: folks_backend_dir / dummy_backend_name,
  install: true,
)

folks_backends += libsocialweb_backend
