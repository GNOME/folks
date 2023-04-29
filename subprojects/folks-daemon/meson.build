project('folks-daemon', 'c',
  version: '1.0.alpha',
  meson_version: '>= 0.59.0',
  default_options: [ 'warning_level=2', 'c_std=gnu11' ],
)

gnome = import('gnome')

config_dic = configuration_data()
config_dic.set_quoted('PACKAGE_VERSION', meson.project_version())
config_dic.set10('HAS_BLUEZ', 'bluez' in get_option('backends'))
config_dic.set10('HAS_EDS', 'eds' in get_option('backends'))
config_h = configure_file(
  output: 'folksd-config.h',
  configuration: config_dic,
)
config_dep = declare_dependency(
  sources: config_h,
  include_directories: include_directories('.'),
)

subdir('src')

