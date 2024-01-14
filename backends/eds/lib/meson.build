eds_backendlib_gir_name = 'FolksEds-@0@'.format(folks_api_version)

eds_backendlib_sources = files(
  'edsf-persona-store.vala',
  'edsf-persona.vala',
)

eds_backendlib_sources += configure_file(
  input: namespace_vala_in,
  output: 'namespace.vala',
  configuration: {
    'BACKENDLIB_GIR_NAME': eds_backendlib_gir_name.split('-')[0],
    'BACKENDLIB_GIR_VERSION': folks_api_version,
    'BACKENDLIB_NAMESPACE': 'Edsf',
  },
)

eds_backendlib_deps = [
  backend_deps,
  libebook_dep,
  libebook_contacts_dep,
  libedataserver_dep,
  libxml_dep,
]

# FIXME: we need to set these manually for the valadoc target as long as meson
# doesn't have native support (https://github.com/mesonbuild/meson/issues/894)
eds_backendlib_doc_deps = [
  '--pkg', 'folks',
  '--pkg', libebook_dep.name(),
]

eds_backendlib_vala_flags = [
  common_backendlib_vala_flags,
]

if eds_dep.version().version_compare('>=3.41')
  eds_backendlib_vala_flags += ['-D', 'HAS_EDS_3_41']
endif

eds_backendlib_c_flags = [
  '-include', 'config.h',
  '-include', 'folks/redeclare-internal-api.h',
  '-DBACKEND_NAME="@0@"'.format(eds_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(eds_backend_name),
]

eds_backendlib_symbolmap = meson.current_source_dir() / 'folks-@0@.map'.format(eds_backend_name)
eds_backendlib_link_flags = cc.get_supported_link_arguments(
  '-Wl,--version-script,@0@'.format(eds_backendlib_symbolmap),
)

eds_backendlib = shared_library('folks-@0@'.format(eds_backend_name),
  eds_backendlib_sources,
  dependencies: eds_backendlib_deps,
  vala_args: eds_backendlib_vala_flags,
  c_args: eds_backendlib_c_flags,
  link_args: eds_backendlib_link_flags,
  link_depends: eds_backendlib_symbolmap,
  version: folks_eds_lib_version,
  vala_header: 'folks/folks-@0@.h'.format(eds_backend_name),
  vala_gir: eds_backendlib_gir_name + '.gir',
  install: true,
  install_dir: [ true, folks_headers_install_dir, true, true ],
)

# Also make sure to install the VAPI's .deps file
install_data('folks-eds.deps',
  install_dir: get_option('datadir') / 'vala' / 'vapi',
)

# FIXME: This comes straight from the Meson docs on how to create/install a
# typelib file for your Vala shared library. However, as mentioned in
# https://github.com/mesonbuild/meson/issues/4481, this is not ideal.
custom_target(eds_backendlib_gir_name + '.typelib',
  command: [ g_ir_compiler,
    '--includedir', libfolks_gir_include_dir,
    '--output', '@OUTPUT@',
    '--shared-library', 'lib' + eds_backendlib.name(),
    meson.current_build_dir() / (eds_backendlib_gir_name + '.gir')
  ],
  output: eds_backendlib_gir_name + '.typelib',
  depends: eds_backendlib,
  install: true,
  install_dir: folks_typelibdir,
)

eds_backendlib_dep = declare_dependency(
  link_with: eds_backendlib,
  include_directories: include_directories('.'),
)

# Pkg-config file
pkgconfig.generate(eds_backendlib,
  name: 'Folks e-d-s support library',
  description: 'Evolution Data Server support library for the Folks meta-contacts library',
  filebase: 'folks-@0@'.format(eds_backend_name),
  requires: [ 'folks', glib_dep, gobject_dep, gee_dep, libebook_dep, libedataserver_dep ],
  variables: common_pkgconf_variables,
)
