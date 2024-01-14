dummy_backendlib_gir_name = 'FolksDummy-@0@'.format(folks_api_version)

dummy_backendlib_sources = files(
  'dummy-backend.vala',
  'dummy-full-persona.vala',
  'dummy-persona-store.vala',
  'dummy-persona.vala',
)

dummy_backendlib_deps = [
  backend_deps,
]

# FIXME: we need to set these manually for the valadoc target as long as meson
# doesn't have native support (https://github.com/mesonbuild/meson/issues/894)
dummy_backendlib_doc_deps = [
  '--pkg', 'folks',
]

dummy_backendlib_vala_flags = [
  common_backendlib_vala_flags,
]

dummy_backendlib_c_flags = [
  '-include', 'config.h',
  '-include', 'folks/redeclare-internal-api.h',
  '-DBACKEND_NAME="@0@"'.format(dummy_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(dummy_backend_name),
]

dummy_backendlib_symbolmap = meson.current_source_dir() / 'folks-@0@.map'.format(dummy_backend_name)
dummy_backendlib_link_flags = cc.get_supported_link_arguments(
  '-Wl,--version-script,@0@'.format(dummy_backendlib_symbolmap),
)

dummy_backendlib = shared_library('folks-@0@'.format(dummy_backend_name),
  dummy_backendlib_sources,
  dependencies: dummy_backendlib_deps,
  vala_args: dummy_backendlib_vala_flags,
  c_args: dummy_backendlib_c_flags,
  link_args: dummy_backendlib_link_flags,
  link_depends: dummy_backendlib_symbolmap,
  version: folks_dummy_lib_version,
  vala_header: 'folks/folks-@0@.h'.format(dummy_backend_name),
  vala_gir: dummy_backendlib_gir_name + '.gir',
  install: true,
  install_dir: [ true, folks_headers_install_dir, true, true ],
)

# Also make sure to install the VAPI's .deps file
install_data('folks-dummy.deps',
  install_dir: get_option('datadir') / 'vala' / 'vapi',
)

# FIXME: This comes straight from the Meson docs on how to create/install a
# typelib file for your Vala shared library. However, as mentioned in
# https://github.com/mesonbuild/meson/issues/4481, this is not ideal.
custom_target(dummy_backendlib_gir_name + '.typelib',
  command: [ g_ir_compiler,
    '--includedir', libfolks_gir_include_dir,
    '--output', '@OUTPUT@',
    '--shared-library', 'lib' + dummy_backendlib.name(),
    meson.current_build_dir() / (dummy_backendlib_gir_name + '.gir')
  ],
  output: dummy_backendlib_gir_name + '.typelib',
  depends: dummy_backendlib,
  install: true,
  install_dir: folks_typelibdir,
)

dummy_backendlib_dep = declare_dependency(
  link_with: dummy_backendlib,
  include_directories: include_directories('.'),
)

# Pkg-config file
pkgconfig.generate(dummy_backendlib,
  name: 'Folks dummy support library',
  description: 'Dummy support library for the Folks meta-contacts library',
  filebase: 'folks-@0@'.format(dummy_backend_name),
  requires: [ 'folks', glib_dep, gobject_dep, gee_dep, ],
  variables: common_pkgconf_variables,
)
