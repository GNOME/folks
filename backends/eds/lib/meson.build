folks_eds_backend_gir_name = 'FolksEds-@0@'.format(folks_api_version)

folks_eds_backend_sources = [
  'edsf-persona-store.vala',
  'edsf-persona.vala',
]

folks_eds_backend_deps = [
  backend_deps,
  libebook,
  libebook_contacts,
  libedataserver,
  libxml,
]

folks_eds_backend_vala_flags = [
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

folks_eds_backend_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(folks_eds_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(folks_eds_backend_name),
]

folks_eds_backend_link_flags = [
  '-Wl,--version-script,@0@/folks-@1@.map'.format(meson.current_source_dir(), folks_eds_backend_name),
]

folks_eds_backend = library('folks-@0@'.format(folks_eds_backend_name),
  folks_eds_backend_sources,
  dependencies: folks_eds_backend_deps,
  vala_args: folks_eds_backend_vala_flags,
  c_args: folks_eds_backend_c_flags,
  link_with: libfolks_internal,
  link_args: folks_eds_backend_link_flags,
  version: folks_eds_lib_version,
  vala_gir: folks_eds_backend_gir_name + '.gir',
  install: true,
  install_dir: [ true, folks_headers_install_dir, true, true ],
)

# FIXME: This comes straight from the Meson docs on how to create/install a
# typelib file for your Vala shared library. However, as mentioned in
# https://github.com/mesonbuild/meson/issues/4481, this is not ideal.
custom_target(folks_eds_backend_gir_name + '.typelib',
  command: [g_ir_compiler, '--output', '@OUTPUT@', join_paths(meson.current_build_dir(), folks_eds_backend_gir_name + '.gir') ],
  output: folks_eds_backend_gir_name + '.typelib',
  depends: folks_eds_backend,
  install: true,
  install_dir: folks_typelibdir,
)

folks_eds_backend_dep = declare_dependency(
  link_with: folks_eds_backend,
  include_directories: include_directories('.'),
)

# Pkg-config file
configure_file(
  input: 'folks-eds.pc.in',
  output: 'folks-eds.pc',
  configuration: pkg_conf,
  install_dir: pkg_install_dir,
)
