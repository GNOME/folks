# in order from least to most complex
keyfile_tests = [
  'individual-retrieval',
]

keyfile_tests_deps = [
  gobject_dep,
  gio_dep,
  gee_dep,
  libfolks_dep,
  libfolks_test_dep,
  libkeyfile_test_dep,
  folks_test_dbus,
]

keyfile_tests_vala_flags = [
  '--debug',
]

foreach _test: keyfile_tests
  test_install_dir = installed_tests_dir / keyfile_backend_name

  test_executable = executable('keyfile-'+_test,
    '@0@.vala'.format(_test),
    dependencies: keyfile_tests_deps,
    vala_args: keyfile_tests_vala_flags,
    install: installed_tests_enabled,
    install_dir: test_install_dir,
  )

  test(_test, test_executable,
    suite: 'KeyfileBackend',
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
      install_dir: installed_tests_meta_dir / keyfile_backend_name
    )
  endif
endforeach
