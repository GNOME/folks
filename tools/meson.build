# folks-inspect
if inspect_tool_enabled
  subdir('inspect')
endif

# folks-import
if import_tool_enabled
  folks_import_sources = [
    'import.vala',
    'import-pidgin.vala',
  ]

  folks_import_deps = [
    build_conf_dep,
    gee_dep,
    gobject_dep,
    glib_dep,
    libfolks_dep,
    libxml_dep,
  ]

  folks_import_vala_flags = [
  ]

  folks_import_c_flags = [
    '-include', 'config.h',
  ]

  folks_import = executable('folks-import',
    folks_import_sources,
    dependencies: folks_import_deps,
    vala_args: folks_import_vala_flags,
    c_args: folks_import_c_flags,
    include_directories: config_h_dir,
    install: true,
  )
endif
