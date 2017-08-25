folks_ofono_backend_name = 'ofono'

folks_ofono_backend_sources = [
  'ofono-backend-factory.vala',
  'ofono-backend.vala',
  'ofono-persona-store.vala',
  'ofono-persona.vala',
  'org-ofono.vala',
]

folks_ofono_backend_deps = [
  backend_deps,
  libebook,
  libedataserver,
]

folks_ofono_backend_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

folks_ofono_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(folks_ofono_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(folks_ofono_backend_name),
]

folks_ofono_backend = library(folks_ofono_backend_name,
  folks_ofono_backend_sources,
  dependencies: folks_ofono_backend_deps,
  vala_args: folks_ofono_backend_vala_flags,
  c_args: folks_ofono_backend_c_flags,
  link_with: libfolks_internal,
  name_prefix: '',
  install_dir: folks_backend_dir / folks_ofono_backend_name,
  install: true,
)

folks_backends += folks_ofono_backend
