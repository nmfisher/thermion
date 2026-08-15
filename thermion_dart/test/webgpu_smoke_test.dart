// Smoke test: create a FilamentApp with Backend.WEBGPU on Linux and tear
// it back down. Requires Filament built with FILAMENT_SUPPORTS_WEBGPU=ON
// (Dawn linked) and a Vulkan ICD on the system — lavapipe is fine for a
// headless CPU run.
//
// Drive with:
//   dart test test/webgpu_smoke_test.dart
//
// The webgpu native code path is gated by THERMION_SUPPORTS_WEBGPU which
// gets set when `hooks.user_defines.thermion_dart.webgpu: true` is in
// pubspec.yaml.
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';

Future<Uint8List> _loadResource(String uri) async {
  uri = uri.replaceAll('file://', '');
  return File(uri).readAsBytesSync();
}

void main() {
  setUpAll(() {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((r) => print(r));
  });

  test('Backend.WEBGPU engine creation + teardown', () async {
    await FFIFilamentApp.create(
      config: FFIFilamentConfig(
        loadResource: _loadResource,
        backend: Backend.WEBGPU,
      ),
    );
    expect(FilamentApp.instance, isNotNull);
    print('WebGPU FilamentApp created successfully on ${Platform.operatingSystem}');
  });
}
