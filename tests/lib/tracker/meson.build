tracker_test_lib_sources = [
  'test-case.vala',
  'backend.vala',
]

tracker_test_lib = library('tracker-test-lib',
  tracker_test_lib_sources,
  dependencies: common_test_lib_deps,
  vala_args: common_test_lib_flags,
)

tracker_test_lib_dep = declare_dependency(
  link_with: tracker_test_lib,
  include_directories: include_directories('.'),
)
