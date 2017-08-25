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
  build_conf_dep,
  libfolks_dep,
  posix_dep,
  readline_dep,
]

folks_inspect_c_flags = [
  '-include', 'config.h',
]

folks_inspect = executable('folks-inspect',
  folks_inspect_sources,
  dependencies: folks_inspect_deps,
  c_args: folks_inspect_c_flags,
  include_directories: config_h_dir,
  install: true,
)
