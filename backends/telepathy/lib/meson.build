folks_telepathy_backend_gir_name = 'FolksTelepathy-@0@'.format(folks_api_version)

# Low-level library
tp_lowlevel_sources = [
  'tp-lowlevel.c',
]

tp_lowlevel_deps = [
  gio,
  gobject,
  telepathy_glib,
]

tp_lowlevel = static_library('tp-lowlevel',
  sources: tp_lowlevel_sources,
  dependencies: tp_lowlevel_deps,
)

tp_lowlevel_gir = gnome.generate_gir(tp_lowlevel,
  sources: [ 'tp-lowlevel.h' ],
  includes: [ 'GObject-2.0', 'TelepathyGLib-0.12' ],
  nsversion: folks_api_version, # XXX check this
  namespace: 'TpLowlevel',
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

# Actual backend library
folks_telepathy_backend_sources = [
  'tpf-logger.vala',
  'tpf-persona-store-cache.vala',
  'tpf-persona-store.vala',
  'tpf-persona.vala',
]

if zeitgeist_enabled
  folks_telepathy_backend_sources += 'tp-zeitgeist.vala'
else
  folks_telepathy_backend_sources += 'tp-zeitgeist-dummy.vala'
endif

folks_telepathy_backend_deps = [
  backend_deps,
  libfolks_internal_dep,
  telepathy_glib,
  tp_lowlevel_dep,
]

folks_telepathy_backend_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

folks_telepathy_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(folks_telepathy_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(folks_telepathy_backend_name),
]

folks_telepathy_backend_link_flags = [
  '-Wl,--version-script,@0@/folks-@1@.map'.format(meson.current_source_dir(), folks_telepathy_backend_name),
]

folks_telepathy_backend = shared_library('folks-@0@'.format(folks_telepathy_backend_name),
  folks_telepathy_backend_sources,
  dependencies: folks_telepathy_backend_deps,
  vala_args: folks_telepathy_backend_vala_flags,
  c_args: folks_telepathy_backend_c_flags,
  link_args: folks_telepathy_backend_link_flags,
  version: folks_telepathy_lib_version,
  vala_gir: folks_telepathy_backend_gir_name + '.gir',
  install: true,
  install_dir: [ true, folks_headers_install_dir, true, true ],
)

# XXX This is giving a SIGSEGV in g-ir-compiler
# FIXME: This comes straight from the Meson docs on how to create/install a
# typelib file for your Vala shared library. However, as mentioned in
# https://github.com/mesonbuild/meson/issues/4481, this is not ideal.
#custom_target(folks_telepathy_backend_gir_name + '.typelib',
#  command: [ g_ir_compiler,
#    '--output', '@OUTPUT@',
#    join_paths(meson.current_build_dir(), folks_telepathy_backend_gir_name + '.gir') ],
#  output: folks_telepathy_backend_gir_name + '.typelib',
#  depends: folks_telepathy_backend,
#  install: true,
#  install_dir: folks_typelibdir,
#)

folks_telepathy_backend_dep = declare_dependency(
  link_with: folks_telepathy_backend,
  include_directories: include_directories('.'),
  dependencies: folks_telepathy_backend_deps,
)

# Pkg-config file
configure_file(
  input: 'folks-telepathy.pc.in',
  output: 'folks-telepathy.pc',
  configuration: pkg_conf,
  install_dir: pkg_install_dir,
)
