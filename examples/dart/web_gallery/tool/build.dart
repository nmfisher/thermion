// Compile the gallery's Dart entry to web/main.wasm with the same compile-time
// version defines the deploy workflow uses, so the local badge matches the
// deployed one. thermion_dart.js/.wasm must already exist in web/ (run
// `dart run thermion_dart:download_web -o web` first if not).
//
//   dart run tool/build.dart          # version read from thermion_dart
//   dart run tool/build.dart --skip-version  # omit defines (badge shows "dev")
import 'dart:io';

void main(List<String> args) async {
  final skipVersion = args.contains('--skip-version');

  final repoRoot = Directory('../..').absolute.path;
  final pubspec = File('$repoRoot/thermion_dart/pubspec.yaml');
  final filamentVersionFile = File('$repoRoot/filament.version');

  var defineArgs = <String>[];
  if (!skipVersion) {
    final versionMatch = RegExp(
      r'^version:\s*(.+)$',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync());
    if (versionMatch == null) {
      stderr.writeln('Could not read version from ${pubspec.path}');
      exit(1);
    }
    final filamentVersion =
        filamentVersionFile.readAsStringSync().trim().split(' ').last;
    defineArgs = [
      '-DTHERMION_VERSION=${versionMatch.group(1)!.trim()}',
      '-DFILAMENT_VERSION=$filamentVersion',
    ];
  }

  final result = await Process.run(
    Platform.resolvedExecutable,
    [
      'compile',
      'wasm',
      'web/main.dart',
      '-o',
      'web/main.wasm',
      ...defineArgs,
    ],
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exit(result.exitCode);
}
