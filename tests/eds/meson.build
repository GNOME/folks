eds_tests_deps = [
  gobject,
  posix,
  libebook,
  libedataserver,
  libxml,
  libfolks_dep,
  libfolks_test_dep,
  libeds_test_dep,
  folks_test_dbus,
  folks_eds_backend_dep,
]

eds_tests_vala_flags = [
  '--debug',
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
  'set-properties',
  'set-properties-race',
  'linkable-properties',
  'link-personas-diff-stores',
  'store-removed',
  'anti-linking',
  'enable-disable-stores',
  'perf',
  'extended-info',
]

foreach _test: eds_tests

  test_executable = executable('eds-'+_test,
    '@0@.vala'.format(_test),
    dependencies: eds_tests_deps,
    vala_args: eds_tests_vala_flags,
  )

  # XXX make a service file

  test('[EDS backend] @0@'.format(_test), test_executable,
    is_parallel: false, # FIXME: https://gitlab.gnome.org/GNOME/folks/issues/69
    env: common_test_environment,
  )
endforeach
