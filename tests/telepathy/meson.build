# in order from least to most complex
telepathy_tests = [
  'persona-store-capabilities',
  'individual-retrieval',
  'individual-properties',
  'init',
]

telepathy_tests_deps = [
  gobject,
  gio,
  gee,
  libfolks_dep,
  libfolks_test_dep,
  telepathy_test_lib_dep,
  folks_test_dbus,
]

telepathy_tests_vala_flags = [
  '--debug',
]

foreach _test: telepathy_tests

  test_executable = executable('telepathy-'+_test,
    '@0@.vala'.format(_test),
    dependencies: telepathy_tests_deps,
    vala_args: telepathy_tests_vala_flags,
  )

  test('[Telepathy backend] @0@'.format(_test),
    test_executable,
    env: common_test_environment,
  )
endforeach
