# folks-inspect
subdir('inspect')

# folks-import
folks_import_sources = [
  'import.vala',
  'import-pidgin.vala',
]

folks_import_deps = [
  gee,
  gobject,
  glib,
  libfolks_dep,
  libxml,
]

folks_import_vala_flags = [
  '--pkg', 'build-conf',
]

folks_import_c_flags = [
  '-include', 'config.h',
]

folks_import = executable('folks-import',
  folks_import_sources,
  dependencies: folks_import_deps,
  vala_args: folks_import_vala_flags,
  c_args: folks_import_c_flags,
  include_directories: config_h_dir,
)
