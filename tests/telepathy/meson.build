# Fake Telepathy backend. For use with client programs such as tests
fake_tp_backend = executable('fake-tp-backend',
  'fake-tp-backend.vala',
  dependencies: [
    libfolks_dep,
    libfolks_test_dep,
    telepathy_test_lib_dep,
    folks_test_dbus,
  ],
)

# in order from least to most complex
telepathy_tests = [
#  'persona-store-capabilities',
#  'individual-retrieval',
#  'individual-properties',
  'init',
]

telepathy_tests_deps = [
  common_test_deps,
  telepathy_test_lib_dep,
]

telepathy_tests_vala_flags = [
  '--debug',
]

foreach _test: telepathy_tests
  test_install_dir = installed_tests_dir / telepathy_backend_name

  test_executable = executable('telepathy-'+_test,
    '@0@.vala'.format(_test),
    dependencies: telepathy_tests_deps,
    vala_args: telepathy_tests_vala_flags,
    install: installed_tests_enabled,
    install_dir: test_install_dir,
  )

  test(_test, test_executable,
    suite: 'Telepathy',
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
      install_dir: installed_tests_meta_dir / telepathy_backend_name
    )
  endif
endforeach
