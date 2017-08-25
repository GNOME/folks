# Backend library
subdir('lib')

# Backend itself
tracker_backend_name = 'tracker'

tracker_backend_sources = [
  'tr-backend-factory.vala',
  'tr-backend.vala',
]

tracker_backend_deps = [
  backend_deps,
  tracker_sparql,
  folks_tracker_backend_dep,
]

tracker_backend_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

tracker_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(tracker_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(tracker_backend_name),
]

tracker_backend = library(tracker_backend_name,
  tracker_backend_sources,
  dependencies: tracker_backend_deps,
  vala_args: tracker_backend_vala_flags,
  c_args: tracker_backend_c_flags,
  link_with: libfolks_internal,
)

folks_backends += tracker_backend
