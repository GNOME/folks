project('folks', [ 'vala', 'c' ],
  version: '0.11.5.0',
  license: 'LGPL2.1+',
  meson_version: '>= 0.49',
)

gnome = import('gnome')
i18n = import('i18n')

# Versions
#-------------------------------------------------

# Core library API version (potentially used for parallel installation)
folks_api_version = '0.6'

# Core library version. When updating this, don't forget to bump the backend
# library versions too, below.
#
# The major version number is additionally used as libfolks' module API version
# number: a given libfolks.so will only load modules which were compiled
# against a core with the same major version as itself. This allows the API
# which is exposed to the modules to be changed.
folks_lib_version = '25.18.4'

# Each of the backend libraries (e.g. libfolks-eds.so; *not* the loadable
# modules, eds.so) has its own version. These should be incremented when the
# core folks_lib_version is incremented (as all the backend libraries are
# binary-dependent on libfolks.so), but should also be incremented when
# incompatible changes are made in the backend library APIs themselves.
folks_eds_lib_version = '25.18.4'
folks_libsocialweb_lib_version = '25.18.4'
folks_telepathy_lib_version = '25.18.4'
folks_tracker_lib_version = '25.18.4'
folks_dummy_lib_version = '25.18.4'

# The module version is used to set the shared object versions
_version_split = folks_lib_version.split('.')
folks_module_version = _version_split[0].to_int() + _version_split[1].to_int()

# Some useful directories
#-------------------------------------------------
folks_prefix = get_option('prefix')
folks_typelibdir = folks_prefix / get_option('libdir') / 'girepository-1.0'
folks_libexecdir = folks_prefix / get_option('libexecdir')
pkg_install_dir = get_option('libdir') / 'pkgconfig'
folks_headers_install_dir = get_option('includedir') / meson.project_name()
installed_tests_dir = folks_libexecdir / 'installed-tests' / meson.project_name()
installed_tests_meta_dir = get_option('datadir') / 'installed-tests' / meson.project_name()

folks_backend_dir = get_option('libdir') / 'folks' / '@0@'.format(folks_module_version) / 'backends'

# Options (see meson_options.txt for more info)
#-------------------------------------------------
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
#-------------------------------------------------
min_glib_version = '2.40'    # Note, we use this for --target-glib as well, so don't add a micro version
min_eds_version = '3.13.90'

valac = meson.get_compiler('vala')
cc = meson.get_compiler('c')

dbus_glib_dep = dependency('dbus-glib-1') # FIXME: get rid of this when our dependencies stop using dbus-1 (GNOME#696177)
gee_dep = dependency('gee-0.8')
gio_dep = dependency('gio-2.0')
glib_dep = dependency('glib-2.0', version: '>=' + min_glib_version)
gmodule_dep = dependency('gmodule-2.0')
gobject_dep = dependency('gobject-2.0', version: '>=' + min_glib_version)
libm_dep = cc.find_library('m')
posix_dep = valac.find_library('posix')
g_ir_compiler = find_program('g-ir-compiler')

valadoc = find_program('valadoc', required: docs_enabled)

if telepathy_backend_enabled
  telepathy_glib_dep = dependency('telepathy-glib', version: '>= 0.19.9')

  if zeitgeist_enabled
    zeitgeist_dep = dependency('zeitgeist-2.0', version: '>= 0.9.14')
  endif
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
  libebook_dep = dependency('libebook-1.2', version: '>=' + min_eds_version)
  libebook_contacts_dep = dependency('libebook-contacts-1.2', version: '>=' + min_eds_version)
  libedataserver_dep = dependency('libedataserver-1.2', version: '>=' + min_eds_version)
  libxml_dep = dependency('libxml-2.0')
endif

if ofono_backend_enabled
  libebook_dep = dependency('libebook-1.2', version: '>=' + min_eds_version)
endif

if bluez_backend_enabled
  libebook_dep = dependency('libebook-1.2', version: '>=' + min_eds_version)
  # Needed for the BlueZ tests
  pymod = import('python')
  py_installation = pymod.find_installation('python3')
  python_dbusmock = py_installation.dependency('dbusmock')
endif

if libsocialweb_backend_enabled
  libsocialweb_dep = dependency('libsocialweb-client', version: '>= 0.25.20')
endif

if import_tool_enabled
  libxml_dep = dependency('libxml-2.0')
endif

if inspect_tool_enabled
  readline_dep = declare_dependency(
    dependencies: [
      cc.find_library('readline'),
      valac.find_library('readline'),
    ]
  )
endif

# Configuration
#-------------------------------------------------
conf = configuration_data()
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('LOCALE_DIR', folks_prefix / get_option('localedir'))
conf.set_quoted('PACKAGE_NAME', meson.project_name())
conf.set_quoted('PACKAGE_STRING', meson.project_name())
conf.set_quoted('PACKAGE_VERSION', meson.project_version())
conf.set_quoted('ABS_TOP_SRCDIR', meson.source_root())
conf.set_quoted('ABS_TOP_BUILDDIR', meson.build_root())
conf.set_quoted('INSTALLED_TESTS_DIR', installed_tests_dir)
conf.set_quoted('INSTALLED_TESTS_META_DIR', folks_prefix / installed_tests_meta_dir)
conf.set_quoted('BACKEND_DIR', folks_prefix / folks_backend_dir)
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

# Vala args
add_project_arguments([
    # Make sure the targets find the build-conf VAPI
    '--vapidir', meson.source_root() / 'folks',
    # within the libfolks tree, select inline code paths
    '-D', 'FOLKS_COMPILATION',
    # Set the target GLib to the minimal version we require as a dependency
    '--target-glib', min_glib_version,
  ],
  language: 'vala'
)

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
#-------------------------------------------------
meson.add_install_script('meson_post_install.py')


# Subdirectories
#-------------------------------------------------

# The core library
subdir('folks')

# The backends

# This will be filed with the backends' build targets (_not_ the libraries)
folks_backends = []

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
