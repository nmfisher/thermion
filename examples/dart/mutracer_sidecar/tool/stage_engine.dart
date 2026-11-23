// Stage the locally built WebGPU web engine into web/.
//
// The engine pair (thermion_dart.js / thermion_dart.wasm) must sit next to
// index.html, which loads it before the Dart entry. Flutter's
// `flutter build web` runs thermion_dart's build hook, which performs that
// copy for `web_local: true` (see pubspec.yaml); `dart compile wasm` does not
// run build hooks at all, so a pure-Dart web app has to stage the engine
// itself. This runs the hook's own publication routine (stageWebEngine:
// atomic publish + journal under web/.thermion-web-engine) with no built-in
// materials — this example's colored skybox and ubershader materials are
// compiled into the engine already.
//
//   dart run tool/stage_engine.dart                         # from the example root
//   dart run tool/stage_engine.dart --engine <dir> --web <dir>
//
// The default engine directory is where
// `scripts/verify_webgpu_prep_build.sh webgpu` drops the WebGPU build.
import 'dart:io';

import 'package:thermion_dart/src/hooks/built_in_materials.dart';

const _defaultEngine =
    '../../../thermion_dart/native/web/build-webgpu/build/out';
const _defaultWeb = 'web';

Never _usage(String message) {
  stderr.writeln(message);
  stderr.writeln(
    'Usage: dart run tool/stage_engine.dart [--engine <dir>] [--web <dir>]',
  );
  exit(64);
}

({String engine, String web}) _parseArgs(List<String> args) {
  var engine = _defaultEngine;
  var web = _defaultWeb;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--engine':
      case '--web':
        if (i + 1 >= args.length) _usage('${args[i]} requires a directory');
        if (args[i] == '--engine') {
          engine = args[++i];
        } else {
          web = args[++i];
        }
      case '-h':
      case '--help':
        stdout.writeln(
          'Usage: dart run tool/stage_engine.dart [--engine <dir>] [--web <dir>]\n'
          '  --engine  directory holding thermion_dart.js/.wasm '
          '(default: $_defaultEngine)\n'
          '  --web    directory to publish into (default: $_defaultWeb)',
        );
        exit(0);
      default:
        _usage('Unknown argument: ${args[i]}');
    }
  }
  return (engine: engine, web: web);
}

void main(List<String> args) async {
  final (:engine, :web) = _parseArgs(args);
  final engineDir = Directory(engine);
  if (!engineDir.existsSync()) {
    stderr.writeln('No engine build at ${engineDir.absolute.path}.');
    stderr.writeln(
      'Build the WebGPU web engine first: scripts/verify_webgpu_prep_build.sh webgpu',
    );
    exit(1);
  }

  // Guard against staging an engine that predates this branch: the sidecar
  // needs Thermion_exportWebGPUDevice and the present-skip swapchain.
  final loader = File('${engineDir.path}/thermion_dart.js');
  if (!loader.existsSync() ||
      !loader.readAsStringSync().contains('thermionWebGPUDevice')) {
    stderr.writeln(
      '${loader.path} does not export Module["thermionWebGPUDevice"]; '
      'it is not a raytracer-webgpu WebGPU engine build.',
    );
    exit(1);
  }

  final webDir = Directory(web)..createSync(recursive: true);
  await stageWebEngine(engineDir, webDir, {}, onLog: stdout.writeln);
  for (final name in ['thermion_dart.js', 'thermion_dart.wasm']) {
    final file = File('${webDir.path}/$name');
    stdout.writeln(
      'Staged ${file.path} (${file.lengthSync() ~/ 1024} KB)',
    );
  }
}
