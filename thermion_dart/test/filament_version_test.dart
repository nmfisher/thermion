import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:test/test.dart';
import 'package:thermion_dart/filament_version.dart';

import '../hook/build.dart' as hook;

void main() {
  test('hosted package resolves the public version without a repository pin', () async {
    final root = Directory.systemTemp.createTempSync('thermion-hosted-version-');
    addTearDown(() => root.deleteSync(recursive: true));
    final package = Directory('${root.path}/thermion_dart')..createSync();
    final cache = Directory('${package.path}/.dart_tool/thermion_dart/lib/$filamentVersion/ios/release')
      ..createSync(recursive: true);
    File('${cache.path}/success').writeAsStringSync('SUCCESS');

    expect(File('${root.path}/filament.version').existsSync(), isFalse);
    final result = await hook.getLibDir(
      package.uri,
      OS.iOS,
      Architecture.arm64,
      Logger('filament_version_test'),
      BuildMode.release,
    );
    expect(result.libDir.path, cache.path);
    expect(result.includeDir.path, '${cache.path}/include');
  });
}
