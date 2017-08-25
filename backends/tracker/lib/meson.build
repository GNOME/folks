tracker_backendlib_gir_name = 'FolksTracker-@0@'.format(folks_api_version)

tracker_backendlib_sources = files(
  'trf-persona-store.vala',
  'trf-persona.vala',
  'trf-util.vala',
)

tracker_backendlib_deps = [
  backend_deps,
  libfolks_internal_dep,
  tracker_sparql_dep,
]

# FIXME: we need to set these manually for the valadoc target as long as meson
# doesn't have native support (https://github.com/mesonbuild/meson/issues/894)
tracker_backendlib_doc_deps = [
  '--pkg', tracker_sparql_dep.name(),
  '--pkg', 'folks',
]

tracker_backendlib_vala_flags = [
  common_backendlib_vala_flags,
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

tracker_backendlib_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(tracker_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(tracker_backend_name),
]

tracker_backendlib_link_flags = [
  '-Wl,--version-script,@0@/folks-@1@.map'.format(meson.current_source_dir(), tracker_backend_name),
]

tracker_backendlib = shared_library('folks-@0@'.format(tracker_backend_name),
  tracker_backendlib_sources,
  dependencies: tracker_backendlib_deps,
  vala_args: tracker_backendlib_vala_flags,
  c_args: tracker_backendlib_c_flags,
  link_args: tracker_backendlib_link_flags,
  version: folks_tracker_lib_version,
  vala_header: 'folks/folks-@0@.h'.format(dummy_backend_name),
  vala_gir: tracker_backendlib_gir_name + '.gir',
  install: true,
  install_dir: [ true, folks_headers_install_dir, true, true ],
)

# FIXME: This comes straight from the Meson docs on how to create/install a
# typelib file for your Vala shared library. However, as mentioned in
# https://github.com/mesonbuild/meson/issues/4481, this is not ideal.
custom_target(tracker_backendlib_gir_name + ' typelib',
  command: [ g_ir_compiler,
    '--output', '@OUTPUT@',
    meson.current_build_dir() / (tracker_backendlib_gir_name + '.gir')
  ],
  output: tracker_backendlib_gir_name + '.typelib',
  depends: tracker_backendlib,
  install: true,
  install_dir: folks_typelibdir,
)

tracker_backendlib_dep = declare_dependency(
  link_with: tracker_backendlib,
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
