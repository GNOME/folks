project('folks', [ 'vala', 'c' ],
  version: '0.11.5.0',
  license: 'LGPL2.1+', # XXX is this ok?
  meson_version: '>= 0.49',
)

gnome = import('gnome')
i18n = import('i18n')

# Add our custom VAPI dir
add_project_arguments([
    '--vapidir', meson.source_root() / 'folks',
    '-D', 'FOLKS_COMPILATION',
  ],
  language: 'vala'
)

# Versions
folks_api_version = '0.6'
# Core library version. When updating this, don't forget to bump the backend
# library versions too, below.
# XXX what about folks_base_version / folks_full_version / folks_maybe_datestamp ?
folks_lib_version = '25.18.4'

_version_split = folks_lib_version.split('.')
folks_module_version = '@0@'.format(_version_split[0].to_int() + _version_split[1].to_int())

folks_eds_lib_version = '25.18.4'
folks_libsocialweb_lib_version = '25.18.4'
folks_telepathy_lib_version = '25.18.4'
folks_tracker_lib_version = '25.18.4'
folks_dummy_lib_version = '25.18.4'

# Some variables
folks_prefix = get_option('prefix')
folks_libdir = folks_prefix / get_option('libdir')
folks_typelibdir = folks_prefix / get_option('libdir') / 'girepository-1.0'
folks_libexecdir = folks_prefix / get_option('libexecdir')
locale_dir = folks_prefix / get_option('localedir')
pkg_install_dir = get_option('libdir') / 'pkgconfig'
folks_headers_install_dir = get_option('includedir') / meson.project_name()
installed_tests_dir = folks_libexecdir / 'installed-tests' / meson.project_name()
installed_tests_meta_dir = folks_prefix / get_option('datadir') / 'installed-tests' / meson.project_name()

folks_backend_dir = folks_libdir / 'folks' / '@0@'.format(folks_module_version) / 'backends'

# Options (see meson_options.txt for more info)
bluez_backend_enabled = get_option('bluez-backend')
docs_enabled = get_option('docs')
eds_backend_enabled = get_option('eds-backend')
installed_tests_enabled = get_option('installed-tests')
libsocialweb_backend_enabled = get_option('libsocialweb-backend')
ofono_backend_enabled = get_option('ofono-backend')
telepathy_backend_enabled = get_option('telepathy-backend')
tracker_backend_enabled = get_option('tracker-backend')
zeitgeist_enabled = get_option('zeitgeist')
import_tool_enabled = get_option('import-tool')
inspect_tool_enabled = get_option('inspect-tool')

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
g_ir_compiler = find_program('g-ir-compiler')
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
  zeitgeist = dependency('zeitgeist-2.0', version: '>= 0.9.14')
endif

if telepathy_backend_enabled
  telepathy_glib = dependency('telepathy-glib', version: '>= 0.19.9')
  #XXX check for zeitgeist
endif

if tracker_backend_enabled
  tracker_sparql_accepted_versions = [ '0.16', '0.18', '1.0', '2.0' ]
  foreach version : tracker_sparql_accepted_versions
    tracker_sparql_dep = dependency('tracker-sparql-@0@'.format(version),
      version: '>= 0.15.2',
      required: false,
    )
    if tracker_sparql_dep.found()
      tracker_sparql_version = version
      break
    endif
  endforeach

  if not tracker_sparql_dep.found()
    error('Tracker backend enabld, but couldn\'t find tracker-sparql package')
  endif
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
conf.set_quoted('BACKEND_DIR', folks_backend_dir)
conf.set10('HAVE_BLUEZ', bluez_backend_enabled)
conf.set10('HAVE_EDS', eds_backend_enabled)
conf.set10('HAVE_LIBSOCIALWEB', libsocialweb_backend_enabled)
conf.set10('HAVE_OFONO', ofono_backend_enabled)
conf.set10('HAVE_TELEPATHY', telepathy_backend_enabled)
conf.set10('HAVE_TRACKER', tracker_backend_enabled)
if tracker_backend_enabled
  conf.set_quoted('TRACKER_SPARQL_MAJOR', tracker_sparql_version)
endif
configure_file(output: 'config.h', configuration: conf)
config_h_dir = include_directories('.')

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
if tracker_backend_enabled
  pkg_conf.set('TRACKER_SPARQL_MAJOR', tracker_sparql_version)
endif

# Post-install scripts
meson.add_install_script('meson_post_install.py')

# The core library
subdir('folks')

# The backends
folks_backends = [] # This will be filed with the backends' build targets
subdir('backends')

folks_backend_paths = [] # Add the backend's paths
foreach backend : folks_backends
  folks_backend_paths += backend.full_path()
endforeach
# Use this variable for FOLKS_BACKEND_PATH in an uninstalled environment
folks_backend_path_uninstalled = ':'.join(folks_backend_paths)

# Helper executables
subdir('tools')

# Translations
subdir('po')

# Tests
subdir('tests')

if docs_enabled
  subdir('docs')
endif