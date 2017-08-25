# Backend library
subdir('lib')

# Backend itself
telepathy_backend_name = 'telepathy'

telepathy_backend_sources = [
  'tp-backend-factory.vala',
  'tp-backend.vala',
]

telepathy_backend_deps = [
  backend_deps,
  telepathy_glib,
  tp_lowlevel_vapi,
  folks_telepathy_backend_dep,
]

telepathy_backend_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

telepathy_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(telepathy_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(telepathy_backend_name),
]

telepathy_backend = library(telepathy_backend_name,
  telepathy_backend_sources,
  dependencies: telepathy_backend_deps,
  vala_args: telepathy_backend_vala_flags,
  c_args: telepathy_backend_c_flags,
  link_with: libfolks_internal,
)

folks_backends += telepathy_backend
