folks_dummy_backend_gir_name = 'FolksDummy-@0@'.format(folks_api_version)

folks_dummy_backend_sources = [
  'dummy-backend.vala',
  'dummy-full-persona.vala',
  'dummy-persona-store.vala',
  'dummy-persona.vala',
]

folks_dummy_backend_deps = [
  backend_deps,
  libfolks_internal_dep,
]

folks_dummy_backend_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

folks_dummy_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(folks_dummy_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(folks_dummy_backend_name),
]

folks_dummy_backend_link_flags = [
  '-Wl,--version-script,@0@/folks-@1@.map'.format(meson.current_source_dir(), folks_dummy_backend_name),
]

folks_dummy_backend = shared_library('folks-@0@'.format(folks_dummy_backend_name),
  folks_dummy_backend_sources,
  dependencies: folks_dummy_backend_deps,
  vala_args: folks_dummy_backend_vala_flags,
  c_args: folks_dummy_backend_c_flags,
  link_args: folks_dummy_backend_link_flags,
  version: folks_dummy_lib_version,
  vala_gir: folks_dummy_backend_gir_name + '.gir',
  install: true,
  install_dir: [ true, folks_headers_install_dir, true, true ],
)

# FIXME: This comes straight from the Meson docs on how to create/install a
# typelib file for your Vala shared library. However, as mentioned in
# https://github.com/mesonbuild/meson/issues/4481, this is not ideal.
custom_target(folks_dummy_backend_gir_name + '.typelib',
  command: [g_ir_compiler, '--output', '@OUTPUT@', join_paths(meson.current_build_dir(), folks_dummy_backend_gir_name + '.gir') ],
  output: folks_dummy_backend_gir_name + '.typelib',
  depends: folks_dummy_backend,
  install: true,
  install_dir: folks_typelibdir,
)

folks_dummy_backend_dep = declare_dependency(
  link_with: folks_dummy_backend,
  include_directories: include_directories('.'),
)

# Pkg-config file
configure_file(
  input: 'folks-dummy.pc.in',
  output: 'folks-dummy.pc',
  configuration: pkg_conf,
  install_dir: pkg_install_dir,
)
