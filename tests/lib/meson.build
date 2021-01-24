# The library that is used by the test libraries
libfolks_test_sources = [
  'disconnection-queue.vala',
  'gtestdbus.c',
  'haze-remove-directory.c',
  'org-freedesktop-dbus-mock.vala',
  'test-case-helper.c',
  'test-case.vala',
  'test-utils.vala',
]

libfolks_test_deps = [
  build_conf_dep,
  libfolks_dep,
  folks_test_dbus,
  posix_dep,
]

libfolks_test_vala_flags = [
  '--debug',
  '-h', 'folks-test-internal.h',
]

libfolks_test = library('folks-test',
  libfolks_test_sources,
  dependencies: libfolks_test_deps,
  vala_args: libfolks_test_vala_flags,
)

libfolks_test_dep = declare_dependency(
  link_with: libfolks_test,
  include_directories: include_directories('.'),
)

# Common variables
common_test_lib_deps = [
  gobject_dep,
  libfolks_dep,
  libfolks_test_dep,
  folks_test_dbus,
]

common_test_lib_flags = [
  '--debug',
]

# Subdirs
subdir('dummy')
subdir('key-file')

if bluez_backend_enabled
  subdir('bluez')
endif

if telepathy_backend_enabled
  subdir('telepathy/contactlist')
  subdir('telepathy')
endif

if eds_backend_enabled
  subdir('eds')
endif

