# in order from least to most complex
dummy_tests = [
  'individual-retrieval',
  'add-persona',
  'linkable-properties',
  'search-view',
]

dummy_tests_deps = [
  common_test_deps,
  dummy_test_lib_dep,
  folks_dummy_backend_dep,
]


foreach _test: dummy_tests
  test_executable = executable('dummy-'+_test,
    '@0@.vala'.format(_test),
    dependencies: dummy_tests_deps,
    vala_args: common_test_vala_flags,
  )

  test(_test, test_executable,
    suite: 'DummyBackend',
    env: common_test_environment,
  )
endforeach
