folks_tracker_backend_gir_name = 'FolksTracker-@0@'.format(folks_api_version)

folks_tracker_backend_sources = [
  'trf-persona-store.vala',
  'trf-persona.vala',
  'trf-util.vala',
]

folks_tracker_backend_deps = [
  backend_deps,
  libfolks_internal_dep,
  tracker_sparql_dep,
]

folks_tracker_backend_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

folks_tracker_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(folks_tracker_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(folks_tracker_backend_name),
]

folks_tracker_backend_link_flags = [
  '-Wl,--version-script,@0@/folks-@1@.map'.format(meson.current_source_dir(), folks_tracker_backend_name),
]

folks_tracker_backend = shared_library('folks-@0@'.format(folks_tracker_backend_name),
  folks_tracker_backend_sources,
  dependencies: folks_tracker_backend_deps,
  vala_args: folks_tracker_backend_vala_flags,
  c_args: folks_tracker_backend_c_flags,
  link_args: folks_tracker_backend_link_flags,
  version: folks_tracker_lib_version,
  vala_gir: folks_tracker_backend_gir_name + '.gir',
  install: true,
  install_dir: [ true, folks_headers_install_dir, true, true ],
)

# FIXME: This comes straight from the Meson docs on how to create/install a
# typelib file for your Vala shared library. However, as mentioned in
# https://github.com/mesonbuild/meson/issues/4481, this is not ideal.
custom_target(folks_tracker_backend_gir_name + ' typelib',
  command: [ g_ir_compiler,
    '--output', '@OUTPUT@',
    meson.current_build_dir() / (folks_tracker_backend_gir_name + '.gir')
  ],
  output: folks_tracker_backend_gir_name + '.typelib',
  depends: folks_tracker_backend,
  install: true,
  install_dir: folks_typelibdir,
)

folks_tracker_backend_dep = declare_dependency(
  link_with: folks_tracker_backend,
  include_directories: include_directories('.'),
  dependencies: tracker_sparql_dep,
)

# Pkg-config file
configure_file(
  input: 'folks-tracker.pc.in',
  output: 'folks-tracker.pc',
  configuration: pkg_conf,
  install_dir: pkg_install_dir,
)
