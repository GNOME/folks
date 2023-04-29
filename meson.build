project('folks', 'c',
  version: '1.0.alpha',
  license: 'LGPL-2.1-or-later',
  meson_version: '>= 0.57',
)

gnome = import('gnome')
i18n = import('i18n')
pkgconfig = import('pkgconfig')

# Versions
#-------------------------------------------------

version_arr = meson.project_version().split('-')[0].split('.')
folks_version_major = version_arr[0].to_int()
folks_version_minor = version_arr[1].to_int()

if version_arr[2].startswith('alpha') or version_arr[2].startswith('beta') or version_arr[2].startswith('rc')
  folks_version_micro = 0
else
  folks_version_micro = version_arr[2].to_int()
endif

# The so major version of the library
folks_soversion = '1'
folks_library_version = '1.@0@.@1@'.format(folks_version_minor, folks_version_micro)

# Core library API version (potentially used for parallel installation)
folks_api_version = folks_version_major

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
docs_enabled = get_option('docs')
tests_enabled = get_option('tests')
installed_tests_enabled = get_option('installed_tests')
import_tool_enabled = get_option('import_tool')
inspect_tool_enabled = get_option('inspect_tool')

# Dependencies
#-------------------------------------------------
min_glib_version = '2.58'
min_eds_version = '3.38'

cc = meson.get_compiler('c')

gio_dep = dependency('gio-2.0')
glib_dep = dependency('glib-2.0', version: '>=' + min_glib_version)
gobject_dep = dependency('gobject-2.0', version: '>=' + min_glib_version)
libm_dep = cc.find_library('m')

if import_tool_enabled
  libxml_dep = dependency('libxml-2.0')
endif

if get_option('profiling')
  sysprof_dep = dependency('sysprof-capture-4', version: '>= 3.38.0')
endif

root_dir = include_directories('.')

# Subdirectories
#-------------------------------------------------

# The core library
subdir('folks')

# Helper executables
subdir('tools')

# Translations
subdir('po')

# Tests
if tests_enabled
#  subdir('tests')
endif

if docs_enabled
  subdir('docs')
endif

subproject('folks-daemon')