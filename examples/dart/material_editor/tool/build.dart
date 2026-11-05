// Compile the editor's Dart entry to web/main.wasm.
// thermion_dart.js/.wasm must already exist in web/ — the build hook fetches
// the runtime-materials variant on `dart pub get`/`dart run` (the pubspec
// sets runtime_materials: true); with a network-less checkout run
// `dart run thermion_dart:download_web -o web` after overriding the variant.
//
//   dart run tool/build.dart
import 'dart:io';

void main(List<String> args) async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    [
      'compile',
      'wasm',
      'web/main.dart',
      '-o',
      'web/main.wasm',
    ],
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exit(result.exitCode);
}
