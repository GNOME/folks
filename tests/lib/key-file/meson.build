libkeyfile_test_sources = [
  'backend.vala',
  'test-case.vala',
]

libkeyfile_test = library('keyfile-test',
  libkeyfile_test_sources,
  dependencies: common_test_lib_deps,
  vala_args: common_test_lib_flags,
)

libkeyfile_test_dep = declare_dependency(
  link_with: libkeyfile_test,
  include_directories: include_directories('.'),
)
