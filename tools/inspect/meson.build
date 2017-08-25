folks_inspect_sources = [
  'command-backends.vala',
  'command-debug.vala',
  'command-help.vala',
  'command-individuals.vala',
  'command-linking.vala',
  'command-persona-stores.vala',
  'command-personas.vala',
  'command-quit.vala',
  'command-search.vala',
  'command-set.vala',
  'command-signals.vala',
  'inspect.vala',
  'signal-manager.vala',
  'utils.vala',
]

folks_inspect_deps = [
  gobject,
  libfolks_dep,
  posix,
  readline,
  gio,
  gee,
]

folks_inspect_vala_flags = [
  '--pkg', 'build-conf',
]

folks_inspect_c_flags = [
  '-include', 'config.h',
]

folks_inspect = executable('folks-inspect',
  folks_inspect_sources,
  dependencies: folks_inspect_deps,
  vala_args: folks_inspect_vala_flags,
  c_args: folks_inspect_c_flags,
  include_directories: config_h_dir,
)
