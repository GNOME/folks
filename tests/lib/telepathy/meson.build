telepathy_test_lib_sources = [
  'test-case-helper.c',
  'test-case.vala',
]

telepathy_test_lib_deps = [
  common_test_lib_deps,
  dbus_glib_dep,
  telepathy_test_contactlist_dep,
  telepathy_backendlib_dep,
  libkeyfile_test_dep,
]

telepathy_test_lib = library('telepathy-test',
  telepathy_test_lib_sources,
  dependencies: telepathy_test_lib_deps,
  vala_args: common_test_lib_flags,
)

telepathy_test_lib_dep = declare_dependency(
  link_with: telepathy_test_lib,
  include_directories: include_directories('.'),
  dependencies: [
    telepathy_backendlib_dep,
    # Exposed by the VAPI
    libkeyfile_test_dep,
    telepathy_test_contactlist_dep,
  ],
)
