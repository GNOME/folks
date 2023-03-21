tracker_backend_name = 'tracker'

# NOTE: we don't export a backend library here.

tracker_backend_sources = [
  'tracker-backend-factory.vala',
  'tracker-backend.vala',
  'tracker-persona-store.vala',
  'tracker-persona.vala',
]

tracker_backend_deps = [
  backend_deps,
  tracker_dep,
  libm_dep,
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

tracker_backend_dep = declare_dependency(
  link_with: tracker_backend,
  include_directories: include_directories('.'),
)

folks_backends += tracker_backend
