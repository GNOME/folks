# in order from least to most complex
keyfile_tests = [
  'individual-retrieval',
]

keyfile_tests_deps = [
  gobject,
  gio,
  gee,
  libfolks_dep,
  libfolks_test_dep,
  libkeyfile_test_dep,
  folks_test_dbus,
]

keyfile_tests_vala_flags = [
  '--debug',
]

foreach _test: keyfile_tests

  test_executable = executable('key-file-'+_test,
    '@0@.vala'.format(_test),
    dependencies: keyfile_tests_deps,
    vala_args: keyfile_tests_vala_flags,
  )

  test(_test, test_executable,
    suite: 'KeyfileBackend',
    env: common_test_environment,
  )
endforeach
