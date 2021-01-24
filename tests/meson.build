# A VAPI for common dbus tests
folks_test_dbus = valac.find_library('folks-test-dbus',
  dirs: meson.current_source_dir() / 'lib',
)

# Test template for installed tests
installed_test_template_in = files('template.test.in')

# Test data & helpers
subdir('data')
subdir('tools')

# Libraries for the tests
subdir('lib')

# Common variables
common_test_deps = [
  libfolks_dep,
  libfolks_test_dep,
  folks_test_dbus,
]

common_test_vala_flags = [
  '--debug',
]

common_test_environment = environment()
common_test_environment.append('FOLKS_BACKEND_PATH', folks_backend_path_uninstalled)

# The tests, grouped in a directory per backend
subdir('dummy')
subdir('key-file')

if bluez_backend_enabled
  subdir('bluez')
endif

if telepathy_backend_enabled
  subdir('telepathy')
  subdir('folks')
endif

if eds_backend_enabled
  subdir('eds')
endif

