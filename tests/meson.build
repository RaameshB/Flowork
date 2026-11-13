test_deps = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gio-2.0'),
  dependency('libadwaita-1', version: '>= 1.4'),
  dependency('libxml-2.0'),
]

schema_dir = meson.current_build_dir()
compile_schemas_test = custom_target('compile-test-schemas',
  input: meson.project_source_root() / 'data/io.github.raameshb.flowork.gschema.xml',
  output: 'gschemas.compiled',
  command: [
    'sh', '-c',
    'cp "$1" "$2/" && glib-compile-schemas "$2"',
    '--', '@INPUT@', schema_dir
  ],
  build_by_default: true,
)

test_timer_exe = executable('test_timer',
  files('test_timer.vala'),
  dependencies: [test_deps, flowork_core_dep],
  link_args: ['-lm'],
)

test('timer-tests', test_timer_exe,
  depends: compile_schemas_test,
  env: [
    'GSETTINGS_BACKEND=memory',
    'GSETTINGS_SCHEMA_DIR=' + schema_dir,
  ],
)

test_statistics_exe = executable('test_statistics',
  files('test_statistics.vala'),
  dependencies: [test_deps, flowork_core_dep],
  link_args: ['-lm'],
)

test('statistics-tests', test_statistics_exe,
  depends: compile_schemas_test,
  env: [
    'GSETTINGS_BACKEND=memory',
    'GSETTINGS_SCHEMA_DIR=' + schema_dir,
  ],
)
