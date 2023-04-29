folks_daemon_dirs = [
  include_directories('.'),
]

folks_daemon_sources = [
  'main.c',
  'folksd-contacts-miner.c',
  'folksd-utils.c',
]

folks_daemon_deps = [
  dependency('glib-2.0', version: '>=2.70'),
  dependency('gobject-2.0'),
  dependency('gio-2.0'),
  dependency('tracker-sparql-3.0'),
]

if 'bluez' in get_option('backends')
  folks_daemon_sources += [
    'bluez/folksd-bluez-miner.c',
    'bluez/folksd-bluez-device-handler.c',
  ]
  folks_daemon_sources += gnome.gdbus_codegen('folksd-bluez-device',
    sources: 'bluez/org.bluez.Device1.xml',
    interface_prefix : 'org.bluez.',
    namespace : 'FolksdBluez',
    object_manager: true,
  )
  folks_daemon_sources += gnome.gdbus_codegen('folksd-bluez-obex-client',
    sources: 'bluez/org.bluez.obex.Client1.xml',
    interface_prefix : 'org.bluez.obex.',
    namespace : 'FolksdBluezObex',
  )
  folks_daemon_sources += gnome.gdbus_codegen('folksd-bluez-obex-transfer',
    sources: 'bluez/org.bluez.obex.Transfer1.xml',
    interface_prefix : 'org.bluez.obex.',
    namespace : 'FolksdBluezObex',
  )
  folks_daemon_sources += gnome.gdbus_codegen('folksd-bluez-obex-phonebook-access',
    sources: 'bluez/org.bluez.obex.PhonebookAccess1.xml',
    interface_prefix : 'org.bluez.obex.',
    namespace : 'FolksdBluezObex',
  )
  folks_daemon_deps += [
    dependency('libebook-contacts-1.2'),
  ]
  folks_daemon_dirs += include_directories('./bluez')
endif

if 'eds' in get_option('backends')
  folks_daemon_sources += [
    'eds/folksd-eds-miner.c',
  ]
  folks_daemon_deps += [
    dependency('libedataserver-1.2'),
    dependency('libebook-contacts-1.2'),
    dependency('libebook-1.2'),
  ]
  folks_daemon_dirs += include_directories('./eds')
endif

executable(meson.project_name(),
  folks_daemon_sources,
  dependencies: [ folks_daemon_deps, config_dep ],
  include_directories: folks_daemon_dirs,
  install: true,
)
