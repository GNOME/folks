folks_public_sources = files(
  'folks-manager.c',
  'folks-persona.c',
  'folks-persona-store.c',
  'folks-structured-name.c',
  'folks-location.c',
)

folks_private_headers = files(
  'folks-persona-store-priv.h',
  'folks-persona-priv.h',
)

folks_public_headers = files(
  'folks.h',
  'folks-manager.h',
  'folks-persona.h',
  'folks-persona-store.h',
  'folks-structured-name.h',
  'folks-location.h',
)

folks_enums = gnome.mkenums_simple(
  'folks-enums',
  sources : folks_public_headers,
  install_header: true,
  install_dir: get_option('prefix') / get_option('includedir') / 'folks@0@/folks'.format(folks_api_version),
)

install_headers(folks_public_headers, subdir: 'folks@0@/folks'.format(folks_api_version))

folks_deps = [
  gobject_dep,
  gio_dep,
  dependency('tracker-sparql-3.0')
]

folks_lib = library('folks@0@'.format(folks_api_version),
  folks_public_sources,
  folks_public_headers,
  folks_private_headers,
  folks_enums,
  dependencies: folks_deps,
  include_directories: root_dir,
  soversion: folks_soversion,
  version: folks_library_version,
  install: true,
)

pkgconfig.generate(
  folks_lib,
  filebase: 'folks@0@'.format(folks_api_version),
  name: 'Folks',
  description: 'The Folks meta-contacts library',
  subdirs: 'folks@0@'.format(folks_api_version),
)

folks_gir = gnome.generate_gir(folks_lib,
  sources: [
    folks_public_sources,
    folks_public_headers,
  ],
  nsversion: folks_api_version.to_string(),
  namespace: 'Folks',
  header: 'folks/folks.h',
  includes: ['GLib-2.0', 'GObject-2.0', 'Gio-2.0'],
  install: true,
)

folks_vapi = gnome.generate_vapi('folks@0@'.format(folks_api_version),
  sources: folks_gir[0],
  packages: [ 'glib-2.0', 'gobject-2.0', 'gio-2.0' ],
  install: true,
)

folks_dep = declare_dependency(
  link_with: folks_lib,
  dependencies: [ folks_vapi, gobject_dep, gio_dep ],
  sources: folks_enums,
  include_directories: root_dir,
)

meson.override_dependency('folks1', folks_dep)