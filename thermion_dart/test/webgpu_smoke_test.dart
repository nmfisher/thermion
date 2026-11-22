// Smoke test: create a FilamentApp with Backend.WEBGPU on Linux and tear
// it back down. Requires Filament built with FILAMENT_SUPPORTS_WEBGPU=ON
// (Dawn linked) and a Vulkan ICD on the system — lavapipe is fine for a
// headless CPU run.
//
// Drive with:
//   dart test test/webgpu_smoke_test.dart
//
// The WebGPU native code path is opt-in: set `backend: webgpu` under
// hooks.user_defines.thermion_dart in pubspec.yaml, which makes the build
// hook define THERMION_SUPPORTS_WEBGPU and link Dawn. Every other build
// (including plain `dart test` in this package) lacks the WebGPU driver,
// so the test probes for it first and skips rather than fails — standard
// runners stay green without the WebGPU toolchain.
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/bindings.dart' as bindings;
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';

Future<Uint8List> _loadResource(String uri) async {
  uri = uri.replaceAll('file://', '');
  return File(uri).readAsBytesSync();
}

/// Whether the loaded libthermion_dart actually has the WebGPU (Dawn)
/// driver compiled in: THERMION_SUPPORTS_WEBGPU + a Filament artifact
/// built with FILAMENT_SUPPORTS_WEBGPU=ON.
///
/// Probed by asking the engine for a BACKEND_WEBGPU instance; Filament
/// returns a null engine for backends it was not built with, so a null
/// result means every WebGPU test would fail here. Runs before the test
/// is registered so the result can drive `skip:`; a successful probe
/// engine is destroyed immediately (it owns no resources beyond the
/// driver/platform).
bool _webgpuCompiledIn() {
  final engine = bindings.Engine_create(
    bindings.TBackend.BACKEND_WEBGPU,
    nullptr.cast<Void>(),
    nullptr.cast<Void>(),
    1,
    false,
  );
  if (engine.address == 0) {
    return false;
  }
  bindings.Engine_destroy(engine);
  return true;
}

void main() {
  setUpAll(() {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((r) => print(r));
  });

  final webgpuAvailable = _webgpuCompiledIn();

  test(
    'Backend.WEBGPU engine creation + teardown',
    () async {
      await FFIFilamentApp.create(
        config: FFIFilamentConfig(loadResource: _loadResource, backend: Backend.WEBGPU),
      );
      expect(FilamentApp.instance, isNotNull);
      print('WebGPU FilamentApp created successfully on ${Platform.operatingSystem}');

      // Tear the engine back down: destroy() flushes and destroys the
      // engine/platform (including the WebGPU platform created in
      // Engine_create) and clears FilamentApp.instance.
      await FilamentApp.instance!.destroy();
      expect(FilamentApp.instance, isNull, reason: "destroy() must clear FilamentApp.instance");
      print('WebGPU FilamentApp destroyed cleanly');
    },
    skip: webgpuAvailable
        ? null
        : 'WebGPU is not compiled into this libthermion_dart build '
              '(requires the `backend: webgpu` user define and a '
              'FILAMENT_SUPPORTS_WEBGPU=ON Filament artifact)',
  );
}
