# Specify some common flags
docs_common_valadoc_flags = [
  '--force',
  '--package-version', # XXX
  '--no-protected',
  '--driver', # XXX
]


# Now build the documentation for each library
custom_target ('valadocs',
  input : libfolks_sources,
  # output : outdir, XXX
  command : [ valadoc,
    docs_common_valadoc_flags,
    '-o', 'folks',
    '--doclet=devhelp',
    '--pkg=gmodule-2.0',
    '--pkg=gio-2.0',
    '--pkg=gee-0.8',
    '--pkg=folks-internal',
    '--pkg=folks-generics',
    '--pkg=build-conf',
    '--wiki=@0@'.format(join_paths(meson.current_source_dir(), 'wiki')),
    '@INPUT@',
  ],
  install : true,
  install_dir : join_paths(get_option('datadir'), 'devhelp', 'books')
)

# TODO also a gtk-doc doclet
# TODO the other libraries
