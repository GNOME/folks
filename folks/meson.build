# Internal library
libfolks_internal_sources = [
  'internal.vala',
  'small-set.c',
]

libfolks_internal_deps = [
  gobject,
  gio,
  gee,
  posix,
]

libfolks_internal = static_library('folks-internal',
  libfolks_internal_sources,
  include_directories: include_directories('..'),
  dependencies: libfolks_internal_deps,
)

libfolks_internal_dep = declare_dependency(
  link_with: libfolks_internal,
)

# Core library
libfolks_gir_name = 'Folks-@0@'.format(folks_api_version)

libfolks_sources = [
  'abstract-field-details.vala',
  'alias-details.vala',
  'anti-linkable.vala',
  'avatar-cache.vala',
  'avatar-details.vala',
  'backend-store.vala',
  'backend.vala',
  'birthday-details.vala',
  'debug.vala',
  'email-details.vala',
  'extended-info.vala',
  'favourite-details.vala',
  'folks-namespace.vala',
  'gender-details.vala',
  'group-details.vala',
  'im-details.vala',
  'individual-aggregator.vala',
  'individual.vala',
  'interaction-details.vala',
  'local-id-details.vala',
  'location-details.vala',
  'name-details.vala',
  'note-details.vala',
  'object-cache.vala',
  'persona-store.vala',
  'persona.vala',
  'phone-details.vala',
  'postal-address-details.vala',
  'potential-match.vala',
  'presence-details.vala',
  'query.vala',
  'role-details.vala',
  'search-view.vala',
  'simple-query.vala',
  'types.vala',
  'url-details.vala',
  'utils.vala',
  'web-service-details.vala',
]

libfolks_deps = [
  gobject,
  gmodule,
  gio,
  gee,
]

libfolks_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

libfolks_c_flags = [
  '-include', 'config.h',
  '-DG_LOG_DOMAIN="folks"',
]

libfolks_lib = shared_library('folks',
  libfolks_sources,
  dependencies: libfolks_deps,
  include_directories: config_h_dir,
  link_with: libfolks_internal,
  vala_args: libfolks_vala_flags,
  c_args: libfolks_c_flags,
  vala_gir: libfolks_gir_name + '.gir',
  version: folks_lib_version,
  install: true,
  install_dir: [ true, folks_headers_install_dir, true, true ],
)

# FIXME: This comes straight from the Meson docs on how to create/install a
# typelib file for your Vala shared library. However, as mentioned in
# https://github.com/mesonbuild/meson/issues/4481, this is not ideal.
custom_target(libfolks_gir_name + '.typelib',
  command: [g_ir_compiler, '--output', '@OUTPUT@', join_paths(meson.current_build_dir(), libfolks_gir_name + '.gir')],
  output: libfolks_gir_name + '.typelib',
  depends: libfolks_lib,
  install: true,
  install_dir: folks_typelibdir,
)
libfolks_gir_include_dir = meson.current_build_dir()

libfolks_dep = declare_dependency(
  link_with: libfolks_lib,
  dependencies: libfolks_deps,
  include_directories: include_directories('.', '..')
)

# GSettings
gsettings_conf = configuration_data()
gsettings_conf.set('GETTEXT_PACKAGE', meson.project_name())
gschema_file = configure_file(
  input: 'org.freedesktop.folks.gschema.xml.in',
  output: 'org.freedesktop.folks.gschema.xml',
  configuration: gsettings_conf,
)
install_data(gschema_file,
  install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas'),
)

# Pkg-config file
configure_file(
  input: 'folks.pc.in',
  output: 'folks.pc',
  configuration: pkg_conf,
  install_dir: pkg_install_dir,
)
