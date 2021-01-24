# Common dependencies
backend_deps = [
  build_conf_dep,
  libfolks_dep,
  libfolks_internal_dep,
]

# Common flags
common_backendlib_vala_flags = [
  # make sure the VAPIs expose the right include path
  '--includedir', meson.project_name(),
]

# Namespace Vala file
#
# FIXME: This can be removed once the backend namespaces have been sanitised.
# https://gitlab.gnome.org/GNOME/folks/issues/73
#
# This file sets namespace and version attributes for GIR.
namespace_vala_in = files('namespace.vala.in')

# A subdirectory for each type of backend
subdir('dummy')
subdir('key-file')

if telepathy_backend_enabled
  subdir('telepathy')
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
