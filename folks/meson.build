folks_build_dir = meson.current_build_dir()

# Internal library
libfolks_internal_sources = [
  'internal.vala',
  'small-set.c',
]

libfolks_internal_deps = [
  gobject_dep,
  gio_dep,
  gee_dep,
  posix_dep,
]

libfolks_internal_vala_flags = []

if get_option('profiling')
  libfolks_internal_vala_flags += '--define=ENABLE_PROFILING'
  libfolks_internal_deps += sysprof_dep
endif

libfolks_internal = static_library('folks-internal',
  libfolks_internal_sources,
  include_directories: include_directories('..'),
  dependencies: libfolks_internal_deps,
  vala_args: libfolks_internal_vala_flags,
)

libfolks_internal_dep = declare_dependency(
  link_with: libfolks_internal,
  dependencies: valac.find_library('folks-generics', dirs: meson.project_source_root() / 'folks'),
)

# Core library
libfolks_gir_name = 'Folks-@0@'.format(folks_api_version)

libfolks_sources = files(
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
)

libfolks_deps = [
  gobject_dep,
  gmodule_dep,
  gio_dep,
  gee_dep,
]

libfolks_vala_flags = [
  '--includedir', meson.project_name(),
]

libfolks_c_flags = [
  '-include', 'config.h',
  '-DG_LOG_DOMAIN="folks"',
]

libfolks_lib = shared_library('folks',
  libfolks_sources,
  dependencies: [ libfolks_deps, build_conf_dep, libfolks_internal_dep ],
  include_directories: config_h_dir,
  vala_args: libfolks_vala_flags,
  c_args: libfolks_c_flags,
  vala_header: 'folks/folks.h',
  vala_gir: libfolks_gir_name + '.gir',
  version: folks_lib_version,
  install: true,
  install_dir: [ true, folks_headers_install_dir, true, true ],
)

# Also make sure to install the VAPI's .deps file
install_data('folks.deps',
  install_dir: get_option('datadir') / 'vala' / 'vapi',
)

# FIXME: This comes straight from the Meson docs on how to create/install a
# typelib file for your Vala shared library. However, as mentioned in
# https://github.com/mesonbuild/meson/issues/4481, this is not ideal.
custom_target(libfolks_gir_name + '.typelib',
  command: [ g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', 'lib' + libfolks_lib.name(),
    meson.current_build_dir() / (libfolks_gir_name + '.gir')
  ],
  output: libfolks_gir_name + '.typelib',
  depends: libfolks_lib,
  install: true,
  install_dir: folks_typelibdir,
)
libfolks_gir_include_dir = meson.current_build_dir()

libfolks_dep = declare_dependency(
  link_with: libfolks_lib,
  include_directories: include_directories('.', '..'),
  dependencies: libfolks_deps,
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
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas',
)

# GConf file
install_data('folks.convert',
  install_dir: get_option('datadir') / 'GConf' / 'gsettings',
)

# Pkg-config file
pkgconfig.generate(libfolks_lib,
  name: 'Folks',
  description: 'The Folks meta-contacts library',
  filebase: 'folks',
  requires: [ glib_dep, gobject_dep, gee_dep, ],
  variables: common_pkgconf_variables,
)
