bluez_backend_name = 'bluez'

# NOTE: we don't export a backend library here.

bluez_backend_sources = [
  'bluez-backend-factory.vala',
  'bluez-backend.vala',
  'bluez-persona-store.vala',
  'bluez-persona.vala',
  'org-bluez-obex-client.vala',
  'org-bluez.vala',
]

bluez_backend_deps = [
  backend_deps,
  libebook_dep,
  libm_dep,
]

bluez_backend_vala_flags = [
]

bluez_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(bluez_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(bluez_backend_name),
]

bluez_backend = shared_module(bluez_backend_name,
  bluez_backend_sources,
  dependencies: bluez_backend_deps,
  vala_args: bluez_backend_vala_flags,
  c_args: bluez_backend_c_flags,
  name_prefix: '',
  install_dir: folks_backend_dir / bluez_backend_name,
  install: true,
)

folks_backends += bluez_backend
