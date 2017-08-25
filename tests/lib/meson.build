# The library that is used by the libraries tests
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
  gobject,
  gio,
  gee,
  dbus_glib,
  libfolks_dep,
  folks_test_dbus,
  posix,
]

libfolks_test_vala_flags = [
  '--debug',
  '--pkg', 'build-conf',
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
  gobject,
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

# XXX
# if telepathy_backend_enabled
#   subdir('telepathy/contactlist')
#   subdir('telepathy')
# endif

if libsocialweb_backend_enabled
  subdir('libsocialweb')
endif

if eds_backend_enabled
  subdir('eds')
endif

if tracker_backend_enabled
  subdir('tracker')
endif
