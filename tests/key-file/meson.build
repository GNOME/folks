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
  #folks_keyfile_backend_dep,
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

  test('[Key-file backend] @0@'.format(_test), test_executable)
endforeach
