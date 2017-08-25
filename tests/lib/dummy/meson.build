dummy_test_lib_sources = [
  'test-case.vala',
]

dummy_test_lib_deps = [
  common_test_lib_deps,
  dummy_backendlib_dep,
]

dummy_test_lib = library('dummy-test',
  dummy_test_lib_sources,
  dependencies: dummy_test_lib_deps,
  vala_args: common_test_lib_flags,
)

dummy_test_lib_dep = declare_dependency(
  link_with: dummy_test_lib,
  include_directories: include_directories('.'),
  dependencies: dummy_backendlib_dep,
)
