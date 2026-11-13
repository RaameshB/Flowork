flowork_core_sources = [
  'XmlUtils.vala',
  'Models/Day.vala',
  'Models/State.vala',
  'Models/InformationHolder.vala',
  'Services/Timer.vala',
  'Services/Statistics.vala',
  'Services/Settings.vala',
]

flowtime_sources = [
  'main.vala',
  'Application.vala',

  # Models
  'Models/StatObject.vala',

  # Services
  'Services/ColorProvider.vala',
  'Services/Alarm.vala',
  'Services/Screensaver.vala',
  'Services/BackgroundStatusReporter.vala',
  'Services/TonePlayer.vala',

  # Widgets
  'Widgets/PreferencesWindow.vala',
  'Widgets/SoundRow.vala',
  'Widgets/StatGraph.vala',
  'Widgets/StatInfo.vala',
  'Widgets/StatList.vala',
  'Widgets/StatPage.vala',
  'Widgets/StatRow.vala',
  'Widgets/StatsWindow.vala',
  'Widgets/TimerPage.vala',
  'Widgets/Window.vala',
]
flowtime_deps = [
  dependency('libadwaita-1', version: '>= 1.4'),
  dependency('libxml-2.0'),
  dependency('libportal-gtk4'),
  meson.get_compiler('c').find_library('m', required: false),
]

conf = configuration_data()
conf.set_quoted('APP_ID', app_id)
conf.set_quoted('G_LOG_DOMAIN', 'Flowork')
conf.set_quoted('VERSION', meson.project_version())
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('DATADIR', join_paths(get_option('prefix'), get_option('datadir')))
conf.set_quoted('GNOMELOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
configure_file(output: 'config.h', configuration: conf)

add_project_arguments(
    '-include', 'config.h',
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    language: 'c'
)

gnome = import('gnome')
blueprint_compiler = find_program('blueprint-compiler')

blueprints = files (
  'ui/preferenceswindow.blp',
  'ui/statrow.blp',
  'ui/statwindow.blp',
  'ui/window.blp',
  'ui/statlist.blp',
  'ui/statinfo.blp',
  'ui/statpage.blp',
  'ui/timerpage.blp',
)

flowork_resources_file = files('flowork.gresource.xml')
flowork_resources = gnome.compile_resources('flowork-resources',
  flowork_resources_file,
  c_name: 'flowork',
  dependencies: custom_target(
    build_always_stale: true,
    command: [blueprint_compiler, 'batch-compile', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@'],
    input: blueprints,
    output: '.',
  ),
)

flowork_core_lib = static_library('flowork-core', flowork_core_sources,
  vala_args: [
    meson.project_source_root() + '/src/vapi/config.vapi',
    '--target-glib=2.50',
    '--enable-checking',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  dependencies: flowtime_deps,
  link_args: ['-lm'],
)

flowork_core_dep = declare_dependency(
  link_with: flowork_core_lib,
  include_directories: include_directories('.'),
)

executable('flowork', flowork_resources, flowtime_sources,
  vala_args: [
    meson.project_source_root() + '/src/vapi/config.vapi',
    '--target-glib=2.50',
    '--enable-checking',
    '--gresourcesdir=src/',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  dependencies: [flowtime_deps, flowork_core_dep],
  install: true,
)
