ofono_backend_name = 'ofono'

ofono_backend_sources = [
  'ofono-backend-factory.vala',
  'ofono-backend.vala',
  'ofono-persona-store.vala',
  'ofono-persona.vala',
  'org-ofono.vala',
]

ofono_backend_deps = [
  backend_deps,
  libebook_dep,
  libedataserver_dep,
]

ofono_backend_vala_flags = [
]

ofono_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(ofono_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(ofono_backend_name),
]

ofono_backend = shared_module(ofono_backend_name,
  ofono_backend_sources,
  dependencies: ofono_backend_deps,
  vala_args: ofono_backend_vala_flags,
  c_args: ofono_backend_c_flags,
  name_prefix: '',
  install_dir: folks_backend_dir / ofono_backend_name,
  install: true,
)

folks_backends += ofono_backend
