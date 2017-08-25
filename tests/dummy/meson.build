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
  dummy_backendlib_dep,
]


foreach _test: dummy_tests
  test_install_dir = installed_tests_dir / dummy_backend_name

  test_executable = executable('dummy-'+_test,
    '@0@.vala'.format(_test),
    dependencies: dummy_tests_deps,
    vala_args: common_test_vala_flags,
    install: installed_tests_enabled,
    install_dir: test_install_dir,
  )

  test(_test, test_executable,
    suite: 'DummyBackend',
    env: common_test_environment,
  )

  if installed_tests_enabled
    configure_file(
      input: installed_test_template_in,
      output: _test + '.test',
      configuration: {
        'libexecdir': folks_libexecdir,
        'installed_tests_dir': test_install_dir,
        'program': _test,
      },
      install_dir: installed_tests_meta_dir / dummy_backend_name
    )
  endif
endforeach
