libsocialweb_test_lib_sources = [
  'test-case.vala',
  'backend.vala',
]

libsocialweb_test_lib = library('libsocialweb-test-lib',
  libsocialweb_test_lib_sources,
  dependencies: common_test_lib_deps,
  vala_args: common_test_lib_flags,
)

libsocialweb_test_lib_dep = declare_dependency(
  link_with: libsocialweb_test_lib,
  include_directories: include_directories('.'),
)
