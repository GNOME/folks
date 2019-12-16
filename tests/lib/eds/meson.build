libeds_test_sources = [
  'backend.vala',
  'test-case.vala',
]

libeds_test_deps = [
  common_test_lib_deps,
  libebook_dep,
  eds_backendlib_dep,
  build_conf_dep,
  libkeyfile_test_dep,
]

libeds_test = library('eds-test',
  libeds_test_sources,
  dependencies: libeds_test_deps,
  vala_args: common_test_lib_flags,
)

libeds_test_dep = declare_dependency(
  link_with: libeds_test,
  include_directories: include_directories('.'),
  dependencies: [
    libkeyfile_test_dep,
  ],
)
