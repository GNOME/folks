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

  test_executable = executable('bluez-'+_test,
    '@0@.vala'.format(_test),
    dependencies: bluez_tests_deps,
    vala_args: bluez_tests_vala_flags,
    link_with: libfolks_internal,
  )

  test('Bluez backend / @0@'.format(_test),
    test_executable,
    env: common_test_environment,
  )
endforeach
