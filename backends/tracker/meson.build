# The tracker backend
tracker_backend_name = 'tracker'

# Backend library
subdir('lib')

tracker_backend_sources = [
  'tr-backend-factory.vala',
  'tr-backend.vala',
]

tracker_backend_deps = [
  backend_deps,
  tracker_sparql_dep,
  tracker_backendlib_dep,
]

tracker_backend_vala_flags = [
]

tracker_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(tracker_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(tracker_backend_name),
]

tracker_backend = shared_library(tracker_backend_name,
  tracker_backend_sources,
  dependencies: tracker_backend_deps,
  vala_args: tracker_backend_vala_flags,
  c_args: tracker_backend_c_flags,
  name_prefix: '',
  install_dir: folks_backend_dir / tracker_backend_name,
  install: true,
)

folks_backends += tracker_backend
