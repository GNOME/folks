# in order from least to most complex
_folks_tests = [
  'small-set',
  'abstract-field-details',
  'async-locking',
  'utils',
  'primary-store-changes',
  'backend-loading',
#  'aggregation',
  'standalone-individuals',
  'avatar-cache',
  'object-cache',
  'phone-field-details',
  'name-details',
#  'init',
]

_folks_tests_deps = [
  common_test_deps,
  libfolks_internal_dep,
  dummy_test_lib_dep,
  telepathy_test_lib_dep,
]

foreach _test: _folks_tests
  test_executable = executable('_folks-'+_test,
    '@0@.vala'.format(_test),
    dependencies: _folks_tests_deps,
    vala_args: common_test_vala_flags,
  )

  test(_test, test_executable,
    suite: 'folks',
    env: common_test_environment,
  )
endforeach
