# in order from least to most complex
bluez_tests = [
  'device-properties',
  'individual-retrieval',
  'vcard-parsing',
]

bluez_tests_deps = [
  common_test_deps,
  libfolks_internal_dep,
  libebook_dep,
  libedataserver_dep,
  libbluez_test_dep,
]

foreach _test: bluez_tests
  test_install_dir = installed_tests_dir / bluez_backend_name

  test_executable = executable('bluez-'+_test,
    '@0@.vala'.format(_test),
    dependencies: bluez_tests_deps,
    vala_args: common_test_vala_flags,
    install: installed_tests_enabled,
    install_dir: test_install_dir,
  )

  test(_test, test_executable,
    suite: 'BluezBackend',
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
      install_dir: installed_tests_meta_dir / bluez_backend_name
    )
  endif
endforeach
