libbluez_test_sources = [
  'test-case.vala',
  'backend.vala',
]

libbluez_test = library('bluez-test',
  libbluez_test_sources,
  dependencies: common_test_lib_deps,
  vala_args: common_test_lib_flags,
)

libbluez_test_dep = declare_dependency(
  link_with: libbluez_test,
  include_directories: include_directories('.'),
)
