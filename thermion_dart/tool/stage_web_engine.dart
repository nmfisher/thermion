// Stage a prebuilt web engine + embedded built-in materials for browser
// tests WITHOUT running them — the prepare half of web_test_runner.dart.
//
// CI uses this to stage an engine on one runner (e.g. a Linux emscripten
// build of the WebGPU engine) and run `dart test -p chrome` on another
// (e.g. macOS, whose Chrome can actually present a WebGPU canvas).
//
// Usage (from the thermion_dart package root):
//   dart run tool/stage_web_engine.dart [--engine-dir=DIR] [--backend=NAME]
//
// --engine-dir defaults to test/embedded_engine (where the generated HTML
// wrappers load the engine, and where CI downloads/unzips engine artifacts).
// The pristine engine is snapshotted to a temp dir first, because
// publishWebMaterials requires source and destination to differ.
// --backend selects the material shader variant (webgpu = WGSL); it defaults
// to the pubspec's hooks.user_defines.thermion_dart backend (web entry when
// the backend is a per-OS map), else webgl2.
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:thermion_dart/src/hooks/built_in_materials.dart';
import 'package:thermion_dart/src/hooks/web_artifacts.dart' show defaultWebBackend;
import 'package:yaml_edit/yaml_edit.dart';

Future<void> main(List<String> args) async {
  var engineDirPath = path.join('test', 'embedded_engine');
  String? backend;
  for (final a in args) {
    if (a.startsWith('--engine-dir=')) {
      engineDirPath = a.substring('--engine-dir='.length);
    } else if (a.startsWith('--backend=')) {
      backend = a.substring('--backend='.length);
    } else {
      stderr.writeln('unknown option: $a');
      exit(64);
    }
  }
  final webDir = Directory(engineDirPath);
  for (final name in ['thermion_dart.js', 'thermion_dart.wasm']) {
    if (!File(path.join(webDir.path, name)).existsSync()) {
      stderr.writeln('Missing ${path.join(webDir.path, name)}; stage the web engine first.');
      exit(1);
    }
  }

  final pubspec = YamlEditor(File('pubspec.yaml').readAsStringSync());
  final defines = pubspec.parseAt(['hooks', 'user_defines', 'thermion_dart'], orElse: () => wrapAsYamlNode(null)).value;
  final materialConfig = defines is Map ? defines['materials'] : null;
  final rawBackend = defines is Map ? defines['backend'] : null;
  final resolvedBackend =
      backend ??
      switch (rawBackend) {
        final String b => b,
        final Map b => (b['web'] ?? defaultWebBackend).toString(),
        _ => defaultWebBackend,
      };

  // Snapshot the pristine engine: publishWebMaterials refuses identical
  // source/destination directories.
  final snapshot = Directory.systemTemp.createTempSync('thermion-engine-src-');
  try {
    for (final name in ['thermion_dart.js', 'thermion_dart.wasm']) {
      File(path.join(webDir.path, name)).copySync(path.join(snapshot.path, name));
    }
    await publishWebMaterials(
      root: Directory.current,
      engineDir: snapshot,
      webDir: webDir,
      materials: selectBuiltInMaterials(materialConfig, onWarning: stderr.writeln),
      backend: resolvedBackend,
      onLog: stderr.writeln,
    );
  } finally {
    snapshot.deleteSync(recursive: true);
  }
  stderr.writeln('Staged engine + materials into ${webDir.path} (backend: $resolvedBackend).');
}
