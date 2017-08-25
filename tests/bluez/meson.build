# in order from least to most complex
bluez_tests = [
  'device-properties',
  'individual-retrieval',
  'vcard-parsing',
]

bluez_tests_deps = [
  gobject,
  gio,
  gee,
  libebook,
  libedataserver,
  libfolks_dep,
  libfolks_test_dep,
  libbluez_test_dep,
  folks_test_dbus,
  folks_bluez_backend_dep,
]

bluez_tests_vala_flags = [
  '--pkg', 'folks-generics',
  '--debug',
]

foreach _test: bluez_tests
  test_install_dir = installed_tests_dir / folks_bluez_backend_name

  test_executable = executable('bluez-'+_test,
    '@0@.vala'.format(_test),
    dependencies: bluez_tests_deps,
    vala_args: bluez_tests_vala_flags,
    link_with: libfolks_internal,
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
      install_dir: installed_tests_meta_dir / folks_bluez_backend_name
    )
  endif
endforeach
