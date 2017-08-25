libsocialweb_backendlib_gir_name = 'FolksLibsocialweb-@0@'.format(folks_api_version)

libsocialweb_backendlib_sources = files(
  'swf-persona-store.vala',
  'swf-persona.vala',
)

libsocialweb_backendlib_deps = [
  backend_deps,
  libfolks_internal_dep,
  libsocialweb_dep,
]

# FIXME: we need to set these manually for the valadoc target as long as meson
# doesn't have native support (https://github.com/mesonbuild/meson/issues/894)
libsocialweb_backendlib_doc_deps = [
  '--pkg', 'libsocialweb-client',
  '--pkg', 'folks',
]

libsocialweb_backendlib_vala_flags = [
  common_backendlib_vala_flags,
  '--pkg', 'folks-generics',
  '--pkg', 'build-conf',
]

libsocialweb_backendlib_c_flags = [
  '-include', 'config.h',
  '-DBACKEND_NAME="@0@"'.format(libsocialweb_backend_name),
  '-DG_LOG_DOMAIN="@0@"'.format(libsocialweb_backend_name),
]

libsocialweb_backendlib_link_flags = [
  '-Wl,--version-script,@0@/folks-@1@.map'.format(meson.current_source_dir(), libsocialweb_backend_name),
]

libsocialweb_backendlib = shared_library('folks-@0@'.format(libsocialweb_backend_name),
  libsocialweb_backendlib_sources,
  dependencies: libsocialweb_backendlib_deps,
  vala_args: libsocialweb_backendlib_vala_flags,
  c_args: libsocialweb_backendlib_c_flags,
  link_args: libsocialweb_backendlib_link_flags,
  version: folks_libsocialweb_lib_version,
  vala_gir: libsocialweb_backendlib_gir_name + '.gir',
  vala_header: 'folks/folks-@0@.h'.format(libsocialweb_backend_name),
  install: true,
  install_dir: [ true, folks_headers_install_dir, true, true ],
)

# FIXME: This comes straight from the Meson docs on how to create/install a
# typelib file for your Vala shared library. However, as mentioned in
# https://github.com/mesonbuild/meson/issues/4481, this is not ideal.
custom_target(libsocialweb_backendlib_gir_name + '.typelib',
  command: [ g_ir_compiler,
    '--includedir', libfolks_gir_include_dir,
    '--output', '@OUTPUT@',
    meson.current_build_dir() / (libsocialweb_backendlib_gir_name + '.gir')
  ],
  output: libsocialweb_backendlib_gir_name + '.typelib',
  depends: libsocialweb_backendlib,
  install: true,
  install_dir: folks_typelibdir,
)

libsocialweb_backendlib_dep = declare_dependency(
  link_with: libsocialweb_backendlib,
  include_directories: include_directories('.'),
  dependencies: libsocialweb_dep,
)

# Pkg-config file
pkgconfig.generate(libsocialweb_backendlib,
  name: 'Folks libsocialweb support library',
  description: 'Libsocialweb support library for the Folks meta-contacts library',
  filebase: 'folks-@0@'.format(libsocialweb_backend_name),
  requires: [ 'folks', glib_dep, gobject_dep, gee_dep, libsocialweb_dep ],
  variables: common_pkgconf_variables,
)
