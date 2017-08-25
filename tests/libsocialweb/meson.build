# in order from least to most complex
libsocialweb_tests = [
  'dummy-lsw',
  'aggregation',
]

libsocialweb_tests_deps = [
  common_test_deps,
  libsocialweb_test_lib_dep,
  folks_libsocialweb_backend_dep,
]


foreach _test: libsocialweb_tests
  test_executable = executable('libsocialweb-'+_test,
    '@0@.vala'.format(_test),
    dependencies: libsocialweb_tests_deps,
    vala_args: common_test_vala_flags,
  )

  test('libsocialweb backend / @0@'.format(_test), test_executable)
endforeach
