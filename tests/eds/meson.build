eds_tests_deps = [
  common_test_deps,
  posix_dep,
  libebook_dep,
  libedataserver_dep,
  libxml_dep,
  libeds_test_dep,
  eds_backendlib_dep,
]

eds_tests_vala_flags = [
  common_test_vala_flags,
]


# First we make the test helpers
helpers = [
  'helper-create-many-contacts',
  'helper-delete-contacts',
  'helper-prepare-aggregator',
]

foreach helper: helpers
  executable(helper,
    '@0@.vala'.format(helper),
    dependencies: eds_tests_deps,
    vala_args: eds_tests_vala_flags,
  )
endforeach

# in order from least to most complex
eds_tests = [
  'persona-store-tests',
  'individual-retrieval',
  'phone-details',
  'email-details',
  'name-details',
  'removing-contacts',
  'updating-phones',
  'updating-contacts',
  'avatar-details',
  'add-persona',
  'im-details',
  'postal-address-details',
  'remove-persona',
  'set-emails',
  'set-im-addresses',
  'link-personas',
  'add-contacts-stress-test',
  # 'set-properties',
  'set-properties-race',
  'linkable-properties',
  'link-personas-diff-stores',
  'store-removed',
  'anti-linking',
  'enable-disable-stores',
  'extended-info',
]

eds_benchmarks = [
  'perf',
]

foreach _test: eds_tests
  test_install_dir = installed_tests_dir / eds_backend_name

  test_executable = executable('eds-'+_test,
    '@0@.vala'.format(_test),
    dependencies: eds_tests_deps,
    vala_args: eds_tests_vala_flags,
    install: installed_tests_enabled,
    install_dir: test_install_dir,
  )

  test(_test, test_executable,
    suite: 'EDSBackend',
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
      install_dir: installed_tests_meta_dir / eds_backend_name
    )
  endif
endforeach

foreach _benchmark: eds_benchmarks

  benchmark_executable = executable('eds-'+_benchmark,
    '@0@.vala'.format(_benchmark),
    dependencies: eds_tests_deps,
    vala_args: eds_tests_vala_flags,
  )

  benchmark(_benchmark, benchmark_executable,
    suite: 'EDSBackend',
    env: common_test_environment,
  )
endforeach
