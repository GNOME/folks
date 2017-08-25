# in order from least to most complex
tracker_tests = [
  'individual-retrieval',
  'name-details-interface',
  'avatar-details-interface',
  'im-details-interface',
  'phone-details-interface',
  'email-details-interface',
  'url-details-interface',
  'favourite-details-interface',
  'fullname-updates',
  'add-contact',
  'default-contact',
  'remove-contact',
  'nickname-updates',
  'family-name-updates',
  'given-name-updates',
  'additional-names-updates',
  'prefix-name-updates',
  'suffix-name-updates',
  'website-updates',
  'favourite-updates',
  'emails-updates',
  'phones-updates',
  'imaddresses-updates',
  'role-details-interface',
  'birthday-details-interface',
  'birthday-updates',
  'note-details-interface',
  'gender-details-interface',
  'postal-address-details-interface',
  'avatar-updates',
  'add-persona',
  'remove-persona',
  'set-nickname',
  'set-favourite',
  'set-phones',
  'set-emails',
  'set-avatar',
  'set-structured-name',
  'set-full-name',
  'set-urls',
  'set-im-addresses',
  'set-postal-addresses',
  'set-roles',
  'set-notes',
  'set-birthday',
  'set-gender',
  'link-personas',
  'duplicated-emails',
  'duplicated-phones',
  'link-personas-via-local-ids',
  'match-im-addresses',
  'match-email-addresses',
  'match-known-emails',
  'match-phone-number',
  'match-name',
  'match-all',
  'set-duplicate-email',
  'set-null-avatar',
]

tracker_tests_deps = [
  common_test_deps,
  tracker_test_lib_dep,
  tracker_backendlib_dep,
]


foreach _test: tracker_tests
  test_install_dir = installed_tests_dir / tracker_backend_name

  test_executable = executable('tracker-'+_test,
    '@0@.vala'.format(_test),
    dependencies: tracker_tests_deps,
    vala_args: common_test_vala_flags,
    install: installed_tests_enabled,
    install_dir: test_install_dir,
  )

  test(_test, test_executable,
    suite: 'TrackerBackend',
    is_parallel: false, # FIXME: https://bugzilla.gnome.org/show_bug.cgi?id=709120
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
      install_dir: installed_tests_meta_dir / tracker_backend_name
    )
  endif
endforeach
