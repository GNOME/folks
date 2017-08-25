project('folks', [ 'vala', 'c' ],
  version: '0.11.5.0',
  license: 'LGPL2.1+', # XXX is this ok?
  meson_version: '>= 0.37',
)

gnome = import('gnome')
i18n = import('i18n')

# Add our custom VAPI dir
# XXX there is not yet a custom VAPI dir :(
add_project_arguments(
  ['--vapidir', join_paths(meson.source_root(), 'folks')],
  language: 'vala'
)

# Versions
api_version = '0.6'

# Some variables
backend_dir = join_paths(meson.source_root(), 'backends')
config_h_dir = include_directories('.')
locale_dir = join_paths(get_option('prefix'), get_option('localedir'))
pkg_install_dir = join_paths(get_option('libdir'), 'pkgconfig')
installed_tests_dir = join_paths(get_option('libexecdir'), 'installed-tests', 'folks') # XXX check that final folder (see InstalledTests on the wiki)
installed_tests_meta_dir = join_paths(get_option('datadir'), 'installed-tests', 'folks') # XXX check that final folder (see InstalledTests on the wiki)
po_dir = join_paths(meson.source_root(), 'po')

# Options (see meson_option.txt for more info)
bluez_backend_enabled = get_option('enable-bluez-backend')
docs_enabled = get_option('enable-docs')
eds_backend_enabled = get_option('enable-eds-backend')
installed_tests_enabled = get_option('enable-installed-tests')
libsocialweb_backend_enabled = get_option('enable-libsocialweb-backend')
modular_tests_enabled = get_option('enable-modular-tests')
ofono_backend_enabled = get_option('enable-ofono-backend')
telepathy_backend_enabled = get_option('enable-telepathy-backend')
tracker_backend_enabled = get_option('enable-tracker-backend')
zeitgeist_enabled = get_option('enable-zeitgeist')
import_tool_enabled = get_option('enable-import-tool')
inspect_tool_enabled = get_option('enable-inspect-tool')

# Dependencies
min_glib_version = '2.40.0'
min_eds_version = '3.13.90'

valac = meson.get_compiler('vala')
cc = meson.get_compiler('c')

# FIXME: get rid of the next 2 when our dependencies stop using dbus-1 (GNOME#696177)
dbus_1 = dependency('dbus-1')
dbus_glib = dependency('dbus-glib-1')
gee = dependency('gee-0.8')
gio = dependency('gio-2.0')
glib = dependency('glib-2.0', version: '>=' + min_glib_version)
gmodule = dependency('gmodule-2.0')
gobject = dependency('gobject-2.0', version: '>=' + min_glib_version)
libm = cc.find_library('m')
posix = valac.find_library('posix')
readline = declare_dependency(
  dependencies: [
    cc.find_library('readline'),
    valac.find_library('readline'),
  ]
)

if docs_enabled
  valadoc = find_program('valadoc')
endif

if zeitgeist_enabled
  zeitgeist = dependency('zeitgeist-2.0')
endif

if telepathy_backend_enabled
  telepathy_glib = dependency('telepathy-glib', version: '>= 0.19.9')
  #XXX check for zeitgeist
endif

if tracker_backend_enabled
  # XXX what the hell does configure.ac do?
  tracker_sparql = dependency('tracker-sparql', version: '>= 0.16')
endif

if eds_backend_enabled
  libebook = dependency('libebook-1.2', version: '>=' + min_eds_version)
  libebook_contacts = dependency('libebook-contacts-1.2', version: '>=' + min_eds_version)
  libedataserver = dependency('libedataserver-1.2', version: '>=' + min_eds_version)
  libxml = dependency('libxml-2.0')
endif

if ofono_backend_enabled
  libebook = dependency('libebook-1.2', version: '>=' + min_eds_version)
endif

if bluez_backend_enabled
  libebook = dependency('libebook-1.2', version: '>=' + min_eds_version)
  # Needed for the BlueZ tests
  python3 = find_program('python3')
  #XXX
endif

if libsocialweb_backend_enabled
endif

if import_tool_enabled
  libxml = dependency('libxml-2.0')
endif


# Configuration
conf = configuration_data()
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('LOCALE_DIR', locale_dir)
conf.set_quoted('PACKAGE_NAME', meson.project_name())
conf.set_quoted('PACKAGE_STRING', meson.project_name())
conf.set_quoted('PACKAGE_VERSION', meson.project_version())
conf.set_quoted('ABS_TOP_SRCDIR', meson.source_root())
conf.set_quoted('ABS_TOP_BUILDDIR', meson.build_root())
conf.set_quoted('INSTALLED_TESTS_DIR', installed_tests_dir)
conf.set_quoted('INSTALLED_TESTS_META_DIR', installed_tests_meta_dir)
conf.set_quoted('BACKEND_DIR', backend_dir)
conf.set10('HAVE_BLUEZ', bluez_backend_enabled)
conf.set10('HAVE_EDS', eds_backend_enabled)
conf.set10('HAVE_LIBSOCIALWEB', libsocialweb_backend_enabled)
conf.set10('HAVE_OFONO', ofono_backend_enabled)
conf.set10('HAVE_TELEPATHY', telepathy_backend_enabled)
conf.set10('HAVE_TRACKER', tracker_backend_enabled)
configure_file(output: 'config.h', configuration: conf)

# Configuration for pc.in files
pkg_conf = configuration_data()
pkg_conf.set('prefix', get_option('prefix'))
pkg_conf.set('exec_prefix', '${prefix}')
pkg_conf.set('libdir', '${prefix}/@0@'.format(get_option('libdir')))
pkg_conf.set('bindir', '${prefix}/@0@'.format(get_option('bindir')))
pkg_conf.set('includedir', '${prefix}/@0@'.format(get_option('includedir')))
pkg_conf.set('datarootdir', '${prefix}/@0@'.format(get_option('datadir')))
pkg_conf.set('datadir', '${datarootdir}')
pkg_conf.set('VERSION', meson.project_version())

# Post-install scripts
meson.add_install_script('meson_post_install.py')

# Subfolders
subdir('folks')
subdir('backends')
subdir('tools')
subdir('po')
# if modular_tests_enabled
  subdir('tests')
# endif
if docs_enabled
  subdir('docs')
endif
