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
  test_install_dir = installed_tests_dir / folks_libsocialweb_backend_name

  test_executable = executable('libsocialweb-'+_test,
    '@0@.vala'.format(_test),
    dependencies: libsocialweb_tests_deps,
    vala_args: common_test_vala_flags,
    install: installed_tests_enabled,
    install_dir: test_install_dir,
  )

  test(_test, test_executable,
    suite: 'libsocialweb',
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
      install_dir: installed_tests_meta_dir / folks_libsocialweb_backend_name
    )
  endif
endforeach
