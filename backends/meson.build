# Common dependencies
backend_deps = [
  libfolks_dep,
  gobject_dep,
  gee_dep,
  gio_dep,
]

# Common flags
common_backendlib_vala_flags = [
  # make sure the VAPIs expose the right include path
  '--includedir', meson.project_name(),
]

# A subdirectory for each type of backend
subdir('dummy')
subdir('key-file')

if telepathy_backend_enabled
  subdir('telepathy')
endif

if libsocialweb_backend_enabled
  subdir('libsocialweb')
endif

if tracker_backend_enabled
  subdir('tracker')
endif

if eds_backend_enabled
  subdir('eds')
endif

if ofono_backend_enabled
  subdir('ofono')
endif

if bluez_backend_enabled
  subdir('bluez')
endif
