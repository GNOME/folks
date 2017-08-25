# Common dependencies
backend_deps = [
  libfolks_dep,
  gobject,
  gee,
  gio
]

# Common flags
backend_vala_flags = [
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
