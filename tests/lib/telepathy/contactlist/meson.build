# Taken from telepathy-glib. The only change is to remove the option to install
# the data files.
#
# PLEASE DO NOT MODIFY THIS CONNECTION MANAGER. Either subclass it,
# copy-and-modify (moving it to a better namespace), or make changes in the
# copy in telepathy-glib first.

telepathy_test_contactlist_sources = [
  'backend.c',
  'contact-list-manager.c',
  'contacts-conn.c',
  'room-list-chan.c',
  'simple-account-manager.c',
  'simple-account.c',
  'simple-conn.c',
  'textchan-null.c',
  'util.c',
]

 telepathy_test_contactlist_headers = [ # Needed for GIR
  'backend.h',
  'contact-list-manager.h',
  'contacts-conn.h',
  'debug.h',
  'room-list-chan.h',
  'simple-account-manager.h',
  'simple-account.h',
  'simple-conn.h',
  'textchan-null.h',
  'util.h',
]

telepathy_test_contactlist_manager = custom_target('tp_test_contact_list.manager',
  output: 'param-spec-struct.h',
  input: 'manager-file.py',
  command: [ test_tools_manager_file_script,
    '@INPUT@',
    meson.current_build_dir(),
  ],
)

telepathy_test_contactlist_deps = [
  glib_dep,
  gio_dep,
  gobject_dep,
  telepathy_glib_dep,
  dbus_glib_dep,
]

telepathy_test_contactlist_lib = shared_library('tp-test-contactlist',
  [ telepathy_test_contactlist_sources, telepathy_test_contactlist_manager ],
  dependencies: telepathy_test_contactlist_deps,
  include_directories: config_h_dir,
)

telepathy_test_contactlist_gir = gnome.generate_gir(telepathy_test_contactlist_lib,
  sources: [ telepathy_test_contactlist_sources, telepathy_test_contactlist_headers ],
  includes: [ 'GObject-2.0', 'TelepathyGLib-0.12' ],
  nsversion: folks_api_version,
  namespace: 'TpTests',
  header: 'tp-test-contactlist.h',
)

telepathy_test_contactlist_vapi = gnome.generate_vapi('tp-test-contactlist',
  sources: telepathy_test_contactlist_gir.get(0),
  packages: [ 'gio-2.0', 'telepathy-glib' ],
)

telepathy_test_contactlist_dep = declare_dependency(
  link_with: telepathy_test_contactlist_lib,
  dependencies: telepathy_test_contactlist_vapi,
)
