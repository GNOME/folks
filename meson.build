project('folks', [ 'vala', 'c' ],
  version: '0.15.10',
  license: 'LGPL-2.1-or-later',
  meson_version: '>= 0.57',
)

gnome = import('gnome')
i18n = import('i18n')
pkgconfig = import('pkgconfig')

# Versions
#-------------------------------------------------

# Core library API version (potentially used for parallel installation)
folks_api_version = '0.7'

# Core library version. When updating this, don't forget to bump the backend
# library versions too, below.
#
# The major version number is additionally used as libfolks' module API version
# number: a given libfolks.so will only load modules which were compiled
# against a core with the same major version as itself. This allows the API
# which is exposed to the modules to be changed.
folks_lib_version = '26.0.0'

# Each of the backend libraries (e.g. libfolks-eds.so; *not* the loadable
# modules, eds.so) has its own version. These should be incremented when the
# core folks_lib_version is incremented (as all the backend libraries are
# binary-dependent on libfolks.so), but should also be incremented when
# incompatible changes are made in the backend library APIs themselves.
folks_eds_lib_version = '26.0.0'
folks_telepathy_lib_version = '26.0.0'
folks_dummy_lib_version = '26.0.0'

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
bluez_backend_enabled = get_option('bluez_backend')
docs_enabled = get_option('docs')
eds_backend_enabled = get_option('eds_backend')
tests_enabled = get_option('tests')
installed_tests_enabled = get_option('installed_tests')
ofono_backend_enabled = get_option('ofono_backend')
telepathy_backend_enabled = get_option('telepathy_backend')
zeitgeist_enabled = get_option('zeitgeist')
import_tool_enabled = get_option('import_tool')
inspect_tool_enabled = get_option('inspect_tool')

# Dependencies
#-------------------------------------------------
min_glib_version = '2.58'
min_eds_version = '3.38'

valac = meson.get_compiler('vala')
cc = meson.get_compiler('c')

gee_dep = dependency('gee-0.8')
gio_dep = dependency('gio-2.0')
glib_dep = dependency('glib-2.0', version: '>=' + min_glib_version)
gmodule_dep = dependency('gmodule-2.0')
gobject_dep = dependency('gobject-2.0', version: '>=' + min_glib_version)
libm_dep = cc.find_library('m')
posix_dep = valac.find_library('posix')
g_ir_compiler = find_program('g-ir-compiler')

if docs_enabled
  valadoc = find_program('valadoc', required: docs_enabled)
endif

if telepathy_backend_enabled
  dbus_glib_dep = dependency('dbus-glib-1')  # FIXME: Drop this, see GNOME/folks#24
  telepathy_glib_dep = dependency('telepathy-glib', version: '>= 0.19.9')

  if zeitgeist_enabled
    zeitgeist_dep = dependency('zeitgeist-2.0', version: '>= 0.9.14')
  endif
endif

if eds_backend_enabled
  libebook_dep = dependency('libebook-1.2', version: '>=' + min_eds_version)
  libebook_contacts_dep = dependency('libebook-contacts-1.2', version: '>=' + min_eds_version)
  libedataserver_dep = dependency('libedataserver-1.2', version: '>=' + min_eds_version)
  libxml_dep = dependency('libxml-2.0')

  eds_dep = dependency('evolution-data-server-1.2', version: '>=' + min_eds_version)
  eds_sources_service_name = eds_dep.get_variable(pkgconfig: 'sourcesdbusservicename')
  eds_address_book_service_name = eds_dep.get_variable(pkgconfig: 'addressbookdbusservicename')

  message('Building E-D-S with Sources service "@0@" AddressBook service "@1@"'.format(
    eds_sources_service_name, eds_address_book_service_name))
endif

if ofono_backend_enabled
  libebook_dep = dependency('libebook-1.2', version: '>=' + min_eds_version)
endif

if bluez_backend_enabled
  libebook_dep = dependency('libebook-1.2', version: '>=' + min_eds_version)
  if tests_enabled
    # Needed for the BlueZ tests
    pymod = import('python')
    py_installation = pymod.find_installation('python3',
      modules: [
        'dbusmock',
      ],
    )
  endif
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

if get_option('profiling')
  sysprof_dep = dependency('sysprof-capture-4', version: '>= 3.38.0')
  add_project_arguments(['--vapidir', meson.current_source_dir() / 'vapi'], language: 'vala')
endif

# Configuration
#-------------------------------------------------
conf = configuration_data()
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('LOCALE_DIR', folks_prefix / get_option('localedir'))
conf.set_quoted('PACKAGE_NAME', meson.project_name())
conf.set_quoted('PACKAGE_STRING', meson.project_name())
conf.set_quoted('PACKAGE_VERSION', meson.project_version())
conf.set_quoted('ABS_TOP_SRCDIR', meson.project_source_root())
conf.set_quoted('ABS_TOP_BUILDDIR', meson.project_build_root())
conf.set_quoted('INSTALLED_TESTS_DIR', installed_tests_dir)
conf.set_quoted('INSTALLED_TESTS_META_DIR', folks_prefix / installed_tests_meta_dir)
conf.set_quoted('BACKEND_DIR', folks_prefix / folks_backend_dir)
conf.set10('HAVE_BLUEZ', bluez_backend_enabled)
conf.set10('HAVE_EDS', eds_backend_enabled)
conf.set10('HAVE_OFONO', ofono_backend_enabled)
conf.set10('HAVE_TELEPATHY', telepathy_backend_enabled)
if eds_backend_enabled
  conf.set_quoted('EDS_SOURCES_SERVICE_NAME', eds_sources_service_name)
  conf.set_quoted('EDS_ADDRESS_BOOK_SERVICE_NAME', eds_address_book_service_name)
endif
configure_file(output: 'config.h', configuration: conf)
config_h_dir = include_directories('.')

build_conf_dep = valac.find_library('build-conf', dirs: meson.current_source_dir() / 'folks')

# Vala args
add_project_arguments([
    # Make sure the targets find the build-conf and folks-internal VAPI
    '--vapidir', meson.project_source_root() / 'folks',
    # within the libfolks tree, select inline code paths
    '-D', 'FOLKS_COMPILATION',
  ],
  language: 'vala'
)

# Configuration for the pkgconfig files
common_pkgconf_variables = [
  'exec_prefix=${prefix}',
  'bindir=${prefix}' / get_option('bindir'),
  'datarootdir=${prefix}' / get_option('datadir'),
  'datadir=${datarootdir}',
  'vapidir=${datarootdir}' / 'vala' / 'vapi',
]

# Post-install scripts
#-------------------------------------------------
gnome.post_install(
  glib_compile_schemas: true,
)


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
if tests_enabled
  subdir('tests')
endif

if docs_enabled
  subdir('docs')
endif
