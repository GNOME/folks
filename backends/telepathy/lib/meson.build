telepathy_backendlib_gir_name = 'FolksTelepathy-@0@'.format(folks_api_version)

# Low-level library
tp_lowlevel_sources = [
  'tp-lowlevel.c',
]

tp_lowlevel_deps = [
  gio_dep,
  gobject_dep,
  telepathy_glib_dep,
]

tp_lowlevel = static_library('tp-lowlevel',
  sources: tp_lowlevel_sources,
  dependencies: tp_lowlevel_deps,
)

tp_lowlevel_gir = gnome.generate_gir(tp_lowlevel,
  sources: [ 'tp-lowlevel.h' ],
  includes: [ 'GObject-2.0', 'TelepathyGLib-0.12' ],
  namespace: 'TpLowlevel',
  nsversion: folks_api_version,
  identifier_prefix: 'FolksTpLowlevel',
  extra_args: [
    '--c-include=tp-lowlevel.h',
  ],
)

tp_lowlevel_vapi = gnome.generate_vapi('tp-lowlevel',
  sources: tp_lowlevel_gir.get(0),
  packages: [ 'gio-2.0', 'telepathy-glib' ],
)

tp_lowlevel_dep = declare_dependency(
  dependencies: tp_lowlevel_vapi,
  link_with: tp_lowlevel,
)

# TP zeitgeist helper library
tp_zeitgeist_deps = [
  gee_dep,
  libfolks_dep,
  telepathy_glib_dep,
]

if zeitgeist_enabled
  tp_zeitgeist_lib = static_library('tp-zeitgeist',
    'tp-zeitgeist.vala',
    dependencies: [ tp_zeitgeist_deps, zeitgeist_dep ],
  )

  tp_zeitgeist_dep = declare_dependency(
    link_with: tp_zeitgeist_lib,
    dependencies: [ tp_zeitgeist_deps, zeitgeist_dep ],
  )
else
  tp_zeitgeist_dummy_lib = static_library('tp-zeitgeist-dummy',
    'tp-zeitgeist-dummy.vala',
    dependencies: tp_zeitgeist_deps,
  )

  tp_zeitgeist_dummy_dep = declare_dependency(
    link_with: tp_zeitgeist_dummy_lib,
    dependencies: tp_zeitgeist_deps,
  )
endif

# Actual backend library
telepathy_backendlib_sources = files(
  'tpf-logger.vala',
  'tpf-persona-store-cache.vala',
  'tpf-persona-store.vala',
  'tpf-persona.vala',
)

telepathy_backendlib_sources += configure_file(
  input: namespace_vala_in,
  output: 'namespace.vala',
  configuration: {
    'BACKENDLIB_GIR_NAME': telepathy_backendlib_gir_name.split('-')[0],
    'BACKENDLIB_GIR_VERSION': folks_api_version,
    'BACKENDLIB_NAMESPACE': 'Tpf',
  },
)

telepathy_backendlib_deps = [
  backend_deps,
  telepathy_glib_dep,
  tp_lowlevel_dep,
]

# FIXME: we need to set these manually for the valadoc target as long as meson
# doesn't have native support (https://github.com/mesonbuild/meson/issues/894)
telepathy_backendlib_doc_deps = [
  '--pkg', 'folks',
  '--pkg', 'tp-lowlevel', '--vapidir', meson.current_build_dir(),
  '--pkg', telepathy_glib_dep.name(),
]

if zeitgeist_enabled
  telepathy_backendlib_deps += tp_zeitgeist_dep
  telepathy_backendlib_doc_deps += [
    '--pkg', 'tp-zeitgeist',
  ]
else
  telepathy_backendlib_deps += tp_zeitgeist_dummy_dep
  telepathy_backendlib_doc_deps += [
    '--pkg', 'tp-zeitgeist-dummy',
  ]
endif

telepathy_backendlib_vala_flags = [
  common_backendlib_vala_flags,
]

telepathy_backendlib_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(telepathy_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(telepathy_backend_name),
]

telepathy_backendlib_symbolmap = meson.current_source_dir() / 'folks-@0@.map'.format(telepathy_backend_name)
telepathy_backendlib_link_flags = cc.get_supported_link_arguments(
  '-Wl,--version-script,@0@'.format(telepathy_backendlib_symbolmap),
)

telepathy_backendlib = shared_library('folks-@0@'.format(telepathy_backend_name),
  telepathy_backendlib_sources,
  dependencies: telepathy_backendlib_deps,
  vala_args: telepathy_backendlib_vala_flags,
  c_args: telepathy_backendlib_c_flags,
  link_args: telepathy_backendlib_link_flags,
  link_depends: telepathy_backendlib_symbolmap,
  version: folks_telepathy_lib_version,
  vala_header: 'folks/folks-@0@.h'.format(telepathy_backend_name),
  vala_gir: telepathy_backendlib_gir_name + '.gir',
  install: true,
  install_dir: [ true, folks_headers_install_dir, true, true ],
)

# Also make sure to install the VAPI's .deps file
install_data('folks-telepathy.deps',
  install_dir: get_option('datadir') / 'vala' / 'vapi',
)

# FIXME: This comes straight from the Meson docs on how to create/install a
# typelib file for your Vala shared library. However, as mentioned in
# https://github.com/mesonbuild/meson/issues/4481, this is not ideal.
custom_target(telepathy_backendlib_gir_name + '.typelib',
  command: [ g_ir_compiler,
    '--includedir', libfolks_gir_include_dir,
    '--output', '@OUTPUT@',
    '--shared-library', 'lib' + telepathy_backendlib.name(),
    meson.current_build_dir() / (telepathy_backendlib_gir_name + '.gir')
  ],
  output: telepathy_backendlib_gir_name + '.typelib',
  depends: telepathy_backendlib,
  install: true,
  install_dir: folks_typelibdir,
)

telepathy_backendlib_dep = declare_dependency(
  link_with: telepathy_backendlib,
  include_directories: include_directories('.'),
  dependencies: telepathy_glib_dep,
)

# Pkg-config file
pkgconfig.generate(telepathy_backendlib,
  name: 'Folks telepathy support library',
  description: 'Telepathy support library for the Folks meta-contacts library',
  filebase: 'folks-@0@'.format(telepathy_backend_name),
  requires: [ 'folks', glib_dep, gobject_dep, gee_dep, telepathy_glib_dep ],
  variables: common_pkgconf_variables,
)
