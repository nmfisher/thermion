import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import '../hook/build.dart' as hook;
import 'package:thermion_dart/filament_version.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('filament-cache-layout-'));
  tearDown(() => root.deleteSync(recursive: true));

  Directory seed(String mode, String suffix) {
    final directory = Directory(
      path.join(root.path, '.dart_tool', 'thermion_dart', 'lib', filamentVersion, 'android', '$mode$suffix'),
    )..createSync(recursive: true);
    File(path.join(directory.path, 'success')).writeAsStringSync('SUCCESS');
    final header = File(path.join(directory.path, 'include', 'bluevk', 'BlueVK.h'));
    header.parent.createSync(recursive: true);
    header.writeAsStringSync('// cached header');
    for (final abi in ['arm64-v8a', 'x86_64']) {
      final library = File(path.join(directory.path, abi, 'libfilament.a'));
      library.parent.createSync(recursive: true);
      library.writeAsStringSync('cached archive');
    }
    return directory;
  }

  test('pinned Android libraries and shared headers use one hash-scoped extraction root', () async {
    const digest = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    File(path.join(root.path, 'filament.libs.json')).writeAsStringSync('{"android/release":"$digest"}');
    seed('release', ''); // A legacy success token must not select legacy contents.
    final expected = seed('release', '-${digest.substring(0, 16)}');
    for (final (architecture, abi) in [(Architecture.arm64, 'arm64-v8a'), (Architecture.x64, 'x86_64')]) {
      final result = await hook.getLibDir(root.uri, OS.android, architecture, Logger('test'), BuildMode.release);
      expect(result.libDir.path, path.join(expected.path, abi));
      expect(File(path.join(result.libDir.path, 'libfilament.a')).existsSync(), isTrue);
      expect(result.includeDir.path, path.join(expected.path, 'include'));
    }
  });

  test('changing the Android pin selects a new root for all ABIs', () async {
    seed('release', '');
    for (final digit in ['a', 'b']) {
      final digest = digit * 64;
      final expected = seed('release', '-${digest.substring(0, 16)}');
      File(path.join(root.path, 'filament.libs.json')).writeAsStringSync('{"android/release":"$digest"}');
      final result = await hook.getLibDir(root.uri, OS.android, Architecture.arm64, Logger('test'), BuildMode.release);
      expect(result.libDir.parent.path, expected.path);
    }
  });

  test('unpinned Android keeps its legacy cache layout', () async {
    final expected = seed('release', '');
    final result = await hook.getLibDir(root.uri, OS.android, Architecture.x64, Logger('test'), BuildMode.release);
    expect(result.libDir.path, path.join(expected.path, 'x86_64'));
    expect(result.includeDir.path, path.join(expected.path, 'include'));
  });
}
